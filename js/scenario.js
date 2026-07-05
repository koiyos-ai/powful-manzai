/* =========================================================================
   パワフル漫才 ─ シナリオエンジン(紙芝居再生機)
   参照: ARCHITECTURE.md §4.1(データ形式・step語彙が正本) / PLAYBOOK.md P1-02

   設計方針(重要・Godot移植を見据える):
   - このファイルは localStorage / pm_save / グローバル S に一切直接触れない。
     状態は必ず呼び出し側(success-play.html等)が ctx 経由で渡す。
     ctx = { S, flags, applyEff(effObj), unlock(key), se(name) }
       - S:      画面側の状態オブジェクト(読み取り専用の想定。書き換えは applyEff 経由)
       - flags:  { seen:{}, vars:{} } 相当(pm_flags)。{player}展開に vars.playerName を使う
       - applyEff(effObj): eff stepの中身をそのまま渡す。適用は呼び出し側の責務
       - unlock(key): unlock stepのkeyをそのまま渡す。記録方法は呼び出し側の責務
       - se(name):   se stepの名前をそのまま渡す。音の実体(WebAudio等)は呼び出し側の責務
   - 呼び出し側は charas(キャラ画像レジストリ)・DOM描画・演出タイミングも本エンジンには持ち込まず、
     本エンジンが提供する「今どのstepで何を表示すべきか」というコールバックに従って描画する。
   ========================================================================= */

(function(global){
  "use strict";

  // ---- step語彙(ARCHITECTURE §4.1): bg / chara / hide / say / choice / label / jump / eff / unlock / se / wait ----

  // {player} 等のプレースホルダをctx.flags.vars展開する。playerNameが無ければ「主人公」既定値。
  function expandPlaceholders(text, ctx){
    if(typeof text!=="string") return text;
    const vars = (ctx && ctx.flags && ctx.flags.vars) || {};
    return text.replace(/\{player\}/g, vars.playerName || "主人公");
  }

  // labelの位置indexを事前に索引化(jump/choiceのgoto解決用)
  function buildLabelIndex(steps){
    const idx={};
    steps.forEach((st,i)=>{ if(st.label!==undefined) idx[st.label]=i; });
    return idx;
  }

  /**
   * 台本を再生する。
   * @param {string} id           - scripts.json のトップレベルキー
   * @param {object} scriptData   - fetch済みの scripts.json 全体(id→台本)、または単一台本オブジェクト
   * @param {object} ctx          - {S, flags, applyEff, unlock, se}
   * @param {function} onEnd      - 再生終了時に呼ばれる(引数なし)
   * @param {object} view         - 描画コールバック群(呼び出し側=UI実装)
   *   view.onBg(bgId)                        背景切替
   *   view.onChara(charaId, face, pos)       立ち絵表示/差替
   *   view.onHide(charaId|"all")             立ち絵を隠す
   *   view.onSay(speakerName, text, face, done) 台詞窓表示。文字送り完了でdone()を呼ぶこと
   *   view.onChoice(options, choose)         選択肢表示。optionsは[{label,goto}]。選んだら choose(goto) を呼ぶ
   *   view.onWait(ms, done)                  待機。doneで再開
   *   view.onEnd()                           オーバーレイを閉じる等の後始末(onEndと別に呼ばれる)
   *
   * タップ仕様(ユーザー確定・厳守・2段階):
   *   1. 文字送り中に画面をタップ → 即全文表示のみ行い、stepは進めない
   *   2. 全文表示済みで画面をタップ → 次のstepへ進む
   *   3. 選択肢表示中は選択肢ボタンのみが反応し、画面タップでは進めない
   * 実装は本関数が返すハンドルの handle.onTap() で表現する。文字送りの実体(タイマー等)はUI側の
   * typeText相当が持つため、エンジンは内部状態(tapState)に応じて「即全文表示させる(view.onSkip)」か
   * 「次stepへ進む」かを振り分けるだけに留める。全文表示完了の通知は view.onSay の done 引数で受け取る。
   */
  function playScript(id, scriptData, ctx, onEnd, view){
    // scriptDataが「id→台本のマップ」なら該当キーを取り出す。単一台本が直接渡された場合はそのまま使う。
    const script = (scriptData && scriptData[id]) ? scriptData[id] : scriptData;
    if(!script || !Array.isArray(script.steps)){
      console.warn("[scenario] script not found or invalid:", id);
      if(onEnd) onEnd();
      return null;
    }
    const steps = script.steps;
    const labelIdx = buildLabelIndex(steps);

    let pc = 0;              // program counter(現stepのindex)
    let ended = false;
    // tapState: 画面全体タップの解釈を決める状態。
    //   "typing"  … say文字送り中。タップ=onSkipで即全文表示を促す(stepは進めない)
    //   "waiting" … 全文表示済み。タップ=次stepへ進む
    //   "choice"  … 選択肢待ち。全画面タップは無視(選択肢ボタンのみ反応)
    //   "busy"    … 上記以外(wait中・eff処理中等)。全画面タップは無視
    let tapState = "busy";

    function finish(){
      if(ended) return;
      ended=true;
      if(view && view.onEnd) view.onEnd();
      if(onEnd) onEnd();
    }

    // 次のstepへ進む(pcをインクリメントしてrunStepへ)。jump/labelはgotoで直接pcを差し替える。
    function gotoIndex(i){
      pc = i;
      runStep();
    }

    function runStep(){
      if(pc>=steps.length){ finish(); return; }
      const st = steps[pc];

      // label自体は何もしない通過点
      if(st.label!==undefined){ pc++; runStep(); return; }

      if(st.jump!==undefined){
        const t = labelIdx[st.jump];
        if(t===undefined){ console.warn("[scenario] jump先が見つかりません:", st.jump); pc++; runStep(); return; }
        gotoIndex(t);
        return;
      }

      if(st.bg!==undefined){
        if(view && view.onBg) view.onBg(st.bg);
        pc++; runStep(); return;
      }

      if(st.chara!==undefined){
        if(view && view.onChara) view.onChara(st.chara, st.face||"base", st.pos||"C");
        pc++; runStep(); return;
      }

      if(st.hide!==undefined){
        if(view && view.onHide) view.onHide(st.hide);
        pc++; runStep(); return;
      }

      if(st.eff!==undefined){
        if(ctx && ctx.applyEff) ctx.applyEff(st.eff);
        pc++; runStep(); return;
      }

      if(st.unlock!==undefined){
        if(ctx && ctx.unlock) ctx.unlock(st.unlock);
        pc++; runStep(); return;
      }

      if(st.se!==undefined){
        if(ctx && ctx.se) ctx.se(st.se);
        pc++; runStep(); return;
      }

      if(st.wait!==undefined){
        tapState = "busy";
        if(view && view.onWait){ view.onWait(st.wait, ()=>{ pc++; runStep(); }); }
        else { pc++; runStep(); }
        return;
      }

      if(st.say!==undefined){
        tapState = "typing"; // 文字送り開始 = タップで即全文表示させたい状態
        const speaker = expandPlaceholders(st.say, ctx);
        const text = expandPlaceholders(st.text||"", ctx);
        if(view && view.onSay){
          // done()はUI側の文字送りが完了した(=全文表示された)瞬間に呼ぶ。
          // これで初めてtapStateが"waiting"になり、次の画面タップでstepが進む。
          view.onSay(speaker, text, st.face, ()=>{ tapState = "waiting"; });
        } else {
          tapState = "waiting";
        }
        return; // 次stepへは進まない。onTap()からのみ進む
      }

      if(st.choice!==undefined){
        tapState = "choice"; // 選択肢待ち。全画面タップは無視、ボタンのみ反応
        const options = st.choice.map(o=>({ label: expandPlaceholders(o.label, ctx), goto:o.goto }));
        const choose = (goto)=>{
          const t = labelIdx[goto];
          if(t===undefined){ console.warn("[scenario] choice先が見つかりません:", goto); pc++; runStep(); return; }
          gotoIndex(t);
        };
        if(view && view.onChoice){
          view.onChoice(options, choose);
        } else {
          // viewが無い場合は先頭の選択肢を自動選択(デバッグ用フォールバック)
          if(options[0]) choose(options[0].goto); else { pc++; runStep(); }
        }
        return;
      }

      // 未知のstep語彙はスキップ(将来拡張のため落とさない)
      console.warn("[scenario] 未知のstep語彙をスキップ:", st);
      pc++; runStep();
    }

    // 画面全体タップ時にUI側が毎回呼ぶ。tapStateに応じて「即全文表示」か「次stepへ」かを振り分ける。
    //   typing  → view.onSkip()を呼び、UI側の文字送りを打ち切らせる(打ち切り完了でtextDone()相当=onSayのdone()が呼ばれ"waiting"になる想定)
    //   waiting → 次stepへ進む
    //   choice/busy → 何もしない(選択肢はview.onChoiceのchooseコールバック、waitはonWaitのdoneが専用の進行経路)
    function onTap(){
      if(ended) return;
      if(tapState==="typing"){
        if(view && view.onSkip) view.onSkip();
      } else if(tapState==="waiting"){
        tapState = "busy";
        pc++; runStep();
      }
      // "choice" / "busy" は無視
    }

    // 再生開始
    runStep();

    return {
      onTap: onTap,
      isChoiceActive: ()=> tapState==="choice"
    };
  }

  global.ScenarioEngine = { playScript: playScript };

})(typeof window!=="undefined" ? window : this);
