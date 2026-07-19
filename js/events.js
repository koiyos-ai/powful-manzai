/* =========================================================================
   パワフル漫才 ─ イベントエンジン(抽選器) P1-04
   参照: ARCHITECTURE.md §4.2 / PLAYBOOK.md P1-04 / EVENTS.md冒頭「発生区分の仕分け」

   設計方針(scenario.jsと同じ):
   - localStorage / pm_save / グローバルS には一切直接触れない。
     イベント定義(data/events.json)と状態(S, flags)は呼び出し側が渡す。
   - 本エンジンは「候補の絞り込み+重み付き抽選」だけを行う。台本再生・seen記録・
     効果適用はすべて呼び出し側(success-play.html)の責務。

   発生率(PLAYBOOK P1-04 手順3: 定数はここにまとめ、調整可能に):
   - cmd:asobi = 0.70(遊びは「何かが起きる」コマンドなので高率)
   - cmd:baito / cmd:rest / cmd:awase = 0.25(通常効果に加えてたまに寸劇)
   - week = 0.15(週送り枠。本番週は呼び出し側で発生させない)
   - theater = 0.25(劇場出番の結果モーダルを閉じた後)
   ========================================================================= */
(function(global){
  "use strict";

  var EVENT_RATES = {
    "cmd:asobi": 0.70,
    "cmd:baito": 0.25,
    "cmd:rest":  0.25,
    "cmd:awase": 0.25,
    "week":      0.15,
    "theater":   0.25
  };

  // cond評価: 現状のdata/events.jsonは全て cond:{} (無条件)。
  // 将来の条件DSL(ARCHITECTURE §9)に備えて既知キーのみ解釈し、未知キーは警告して真扱い。
  //   minPop/maxPop, minTrust/maxTrust, minTurn/maxTurn, kontoUnlocked(bool)
  function condOk(cond, S){
    if(!cond) return true;
    for(var k in cond){
      var v=cond[k];
      switch(k){
        case "minPop":   if(!S || (S.pop|0)   < v) return false; break;
        case "maxPop":   if(!S || (S.pop|0)   > v) return false; break;
        case "minTrust": if(!S || (S.trust|0) < v) return false; break;
        case "maxTrust": if(!S || (S.trust|0) > v) return false; break;
        case "minTurn":  if(!S || (S.turn|0)  < v) return false; break;
        case "maxTurn":  if(!S || (S.turn|0)  > v) return false; break;
        case "kontoUnlocked": if(!S || !!S.kontoUnlocked !== !!v) return false; break;
        default:
          console.warn("[events] 未知のcondキー(真扱い):", k);
      }
    }
    return true;
  }

  /**
   * プール一致→cond真→once未消化 の候補から重み付き抽選で1件返す。候補が無ければnull。
   * @param {string} pool    - "cmd:asobi" / "week" / "theater" 等
   * @param {object} S       - 育成状態(読み取りのみ)
   * @param {object} flags   - pm_flags相当 { seen:{}, vars:{} }。onceの消化判定に seen[イベントid] を使う
   * @param {object} events  - data/events.json の中身(id→定義)
   * @returns {object|null}  - 当選したイベント定義
   */
  function pickEvent(pool, S, flags, events){
    if(!events) return null;
    var seen=(flags&&flags.seen)||{};
    var cands=[], total=0;
    for(var id in events){
      var ev=events[id];
      if(!ev || ev.pool!==pool) continue;
      if(ev.once && seen[ev.id||id]) continue;
      if(!condOk(ev.cond, S)) continue;
      var w=(typeof ev.weight==="number" && ev.weight>0)?ev.weight:10;
      cands.push({ev:ev,w:w}); total+=w;
    }
    if(!cands.length) return null;
    var r=Math.random()*total, acc=0;
    for(var i=0;i<cands.length;i++){
      acc+=cands[i].w;
      if(r<=acc) return cands[i].ev;
    }
    return cands[cands.length-1].ev;
  }

  global.EventEngine = { EVENT_RATES:EVENT_RATES, pickEvent:pickEvent };
})(this);
