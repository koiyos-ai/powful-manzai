/* ===========================================================
   データ定義（03_NETA / SCORING の設計に準拠）
   =========================================================== */
// 形式: shab=しゃべくり / konto=コント
let currentForm = "shab";

// スロット定義: 1番ツカミ固定, 9番オチ固定, 2-8自由
// kind: 配置可能な種別。固定枠は種別固定。
const SLOTS = [
  {pos:1, role:"ツカミ", fixed:true,  accept:["ツカミ"]},
  {pos:2, role:"フリ",   fixed:false, accept:["フリ","ボケ","ツッコミ"]},
  {pos:3, role:"自由",   fixed:false, accept:["フリ","ボケ","ツッコミ"]},
  {pos:4, role:"自由",   fixed:false, accept:["フリ","ボケ","ツッコミ"]},
  {pos:5, role:"自由",   fixed:false, accept:["フリ","ボケ","ツッコミ"]},
  {pos:6, role:"自由",   fixed:false, accept:["フリ","ボケ","ツッコミ"]},
  {pos:7, role:"自由",   fixed:false, accept:["フリ","ボケ","ツッコミ"]},
  {pos:8, role:"自由",   fixed:false, accept:["フリ","ボケ","ツッコミ"]},
  {pos:9, role:"オチ",   fixed:true,  accept:["オチ"]},
];

// パーツ図鑑（id, 種別kind, 質タグtag, 威力pow, 形式form: both=共有/shab/konto）
// ツカミ・オチは形式共有(both)。フリ・ボケ・ツッコミは形式ごと。
let PID = 0;
function mk(kind,tag,pow,form){return {id:"p"+(PID++),kind,tag,pow,form};}
const STOCK = [
  // ツカミ(形式共有)
  mk("ツカミ","自己紹介",5,"both"), mk("ツカミ","ギャグ",6,"both"),
  // オチ(形式共有)
  mk("オチ","回収",8,"both"), mk("オチ","裏切り",7,"both"),
  // ----- しゃべくり用 -----
  mk("フリ","日常",6,"shab"), mk("フリ","説明",5,"shab"), mk("フリ","持論",7,"shab"), mk("フリ","妄想",4,"shab"),
  mk("ボケ","あるある",6,"shab"), mk("ボケ","誇張",8,"shab"), mk("ボケ","裏切り",7,"shab"),
  mk("ボケ","動き",5,"shab"), mk("ボケ","ひねり",7,"shab"),
  mk("ツッコミ","直球",7,"shab"), mk("ツッコミ","例え",6,"shab"), mk("ツッコミ","ノリ",6,"shab"),
  mk("ツッコミ","説明",5,"shab"), mk("ツッコミ","スカシ",7,"shab"),
  mk("ボケ","あるある",4,"shab"), mk("ツッコミ","直球",5,"shab"),
  // ----- コント用 -----
  mk("フリ","日常",5,"konto"), mk("フリ","説明",7,"konto"), mk("フリ","持論",6,"konto"), mk("フリ","妄想",6,"konto"),
  mk("ボケ","あるある",6,"konto"), mk("ボケ","誇張",7,"konto"), mk("ボケ","裏切り",6,"konto"),
  mk("ボケ","動き",8,"konto"), mk("ボケ","ひねり",5,"konto"),
  mk("ツッコミ","直球",6,"konto"), mk("ツッコミ","例え",5,"konto"), mk("ツッコミ","ノリ",8,"konto"),
  mk("ツッコミ","説明",6,"konto"), mk("ツッコミ","スカシ",6,"konto"),
  mk("ボケ","動き",5,"konto"), mk("ツッコミ","ノリ",6,"konto"),
];

// 配置状態: slotPos -> partId (or null)
// 配置状態: 形式ごとに別々に保持（しゃべくり打線とコント打線を独立管理）
// placements = { shab:{1:pid,...}, konto:{1:pid,...} }
const placements = {shab:{}, konto:{}};
SLOTS.forEach(s=>{placements.shab[s.pos]=null; placements.konto[s.pos]=null;});
// 現在の形式の配置を返すプロキシ的アクセサ
function placementGet(pos){return placements[currentForm][pos];}
function placementSet(pos,val){placements[currentForm][pos]=val;}
// 互換用: placement[pos] の読み書きを現在形式に向ける
const placement = new Proxy({}, {
  get(_,prop){ if(prop==="__isProxy")return true; return placements[currentForm][prop]; },
  set(_,prop,val){ placements[currentForm][prop]=val; return true; },
  ownKeys(){ return Object.keys(placements[currentForm]); },
  getOwnPropertyDescriptor(){ return {enumerable:true,configurable:true}; }
});

/* ===========================================================
   コンボ定義（小14 / 中9 / 役満4）発動条件の判定
   =========================================================== */
// ネタを「位置順のパーツ配列」にして判定する
function getPlacedParts(){
  return SLOTS.map(s=>{
    const pid=placement[s.pos];
    if(!pid) return null;
    const p=STOCK.find(x=>x.id===pid);
    return p?{...p,pos:s.pos}:null;
  });
}
// 中間7枠(2-8)のパーツ
function midParts(arr){return arr.filter(p=>p&&p.pos>=2&&p.pos<=8);}

// 順序型ヘルパ: tagA(kindA)の直後にtagB(kindB)が来る箇所があるか（隣接）
function hasAdjPair(arr,kindA,tagA,kindB,tagB){
  for(let i=0;i<arr.length-1;i++){
    const a=arr[i],b=arr[i+1];
    if(a&&b&&a.kind===kindA&&a.tag===tagA&&b.kind===kindB&&b.tag===tagB)return true;
  }
  return false;
}
// 存在型: 条件を満たすパーツが存在するか
function hasPart(arr,kind,tag){return arr.some(p=>p&&p.kind===kind&&p.tag===tag);}
function countPart(arr,kind,tag){return arr.filter(p=>p&&p.kind===kind&&p.tag===tag).length;}

// コンボ判定本体 → 成立コンボ配列[{name,rank}]
function detectCombos(){
  const arr=getPlacedParts();
  const mid=midParts(arr);
  const res=[];
  const add=(name,rank)=>res.push({name,rank});

  // ---- 小コンボ(14) ----
  if(hasAdjPair(arr,"フリ","日常","ボケ","あるある")) add("あるあるネタ","small");
  if(hasAdjPair(arr,"フリ","持論","ボケ","誇張")) add("熱弁","small");
  if(hasAdjPair(arr,"フリ","説明","ボケ","裏切り")) add("肩透かし","small");
  if(hasAdjPair(arr,"ボケ","あるある","ツッコミ","直球")) add("ど真ん中","small");
  if(hasAdjPair(arr,"ボケ","誇張","ツッコミ","直球")) add("一刀両断","small");
  if(hasAdjPair(arr,"ボケ","裏切り","ツッコミ","スカシ")) add("柳に風","small");
  if(hasAdjPair(arr,"ボケ","誇張","ツッコミ","例え")) add("言い得て妙","small");
  if(hasAdjPair(arr,"ボケ","あるある","ツッコミ","ノリ")) add("あるあるノリ","small");
  if(hasAdjPair(arr,"ボケ","動き","ツッコミ","ノリ")) add("悪乗り","small");
  // 天丼: 同威力・同性質(同tag)のボケが2つ以上
  (function(){
    const bokes=arr.filter(p=>p&&p.kind==="ボケ");
    const seen={};
    for(const b of bokes){const k=b.tag+"_"+b.pow; if(seen[k]){add("天丼","small");break;} seen[k]=1;}
  })();
  // 先手必勝: 1番ギャグツカミ + 2番がボケ
  if(arr[0]&&arr[0].tag==="ギャグ"&&arr[1]&&arr[1].kind==="ボケ") add("先手必勝","small");
  // 伏線回収: 説明フリ + 回収オチ(存在)
  if(hasPart(arr,"フリ","説明")&&hasPart(arr,"オチ","回収")) add("伏線回収","small");
  // 二段オチ: 裏切りボケ + 裏切りオチ
  if(hasPart(arr,"ボケ","裏切り")&&hasPart(arr,"オチ","裏切り")) add("二段オチ","small");
  // 緩急: フリとボケの威力差5以上(隣接でなく存在ベースで最大差)
  (function(){
    const furi=arr.filter(p=>p&&p.kind==="フリ"), boke=arr.filter(p=>p&&p.kind==="ボケ");
    for(const f of furi)for(const b of boke){if(Math.abs(f.pow-b.pow)>=5){add("緩急","small");return;}}
  })();

  // ---- 中コンボ(9) ----
  // 教科書: 日常フリ→あるあるボケ→直球ツッコミ(連続3)
  for(let i=0;i<arr.length-2;i++){
    const a=arr[i],b=arr[i+1],c=arr[i+2];
    if(a&&b&&c&&a.kind==="フリ"&&a.tag==="日常"&&b.kind==="ボケ"&&b.tag==="あるある"&&c.kind==="ツッコミ"&&c.tag==="直球"){add("教科書","medium");break;}
  }
  // 起承転結: 説明フリ→任意ボケ→裏切りボケ→回収オチ(順序)
  (function(){
    const idxSetsu=arr.findIndex(p=>p&&p.kind==="フリ"&&p.tag==="説明");
    if(idxSetsu<0)return;
    let idxBoke=-1;for(let i=idxSetsu+1;i<arr.length;i++){if(arr[i]&&arr[i].kind==="ボケ"){idxBoke=i;break;}}
    if(idxBoke<0)return;
    let idxUra=-1;for(let i=idxBoke+1;i<arr.length;i++){if(arr[i]&&arr[i].kind==="ボケ"&&arr[i].tag==="裏切り"){idxUra=i;break;}}
    if(idxUra<0)return;
    let idxKai=-1;for(let i=idxUra+1;i<arr.length;i++){if(arr[i]&&arr[i].kind==="オチ"&&arr[i].tag==="回収"){idxKai=i;break;}}
    if(idxKai>=0)add("起承転結","medium");
  })();
  // 波状攻撃: 誇張ボケ→直球ツッコミ のペアが2組以上
  (function(){
    let c=0;for(let i=0;i<arr.length-1;i++){const a=arr[i],b=arr[i+1];if(a&&b&&a.kind==="ボケ"&&a.tag==="誇張"&&b.kind==="ツッコミ"&&b.tag==="直球")c++;}
    if(c>=2)add("波状攻撃","medium");
  })();
  // マシンガン: ボケ4連続
  (function(){
    let run=0;for(const p of arr){if(p&&p.kind==="ボケ"){run++;if(run>=4){add("マシンガン","medium");break;}}else run=0;}
  })();
  // 熱演(コント): 動きボケ2+ノリツッコミ2
  if(currentForm==="konto"&&countPart(arr,"ボケ","動き")>=2&&countPart(arr,"ツッコミ","ノリ")>=2) add("熱演","medium");
  // 伏線過多: 説明フリ2+回収オチ
  if(countPart(arr,"フリ","説明")>=2&&hasPart(arr,"オチ","回収")) add("伏線過多","medium");
  // 名人芸(しゃべくり): 例えツッコミ1+スカシツッコミ1
  if(currentForm==="shab"&&hasPart(arr,"ツッコミ","例え")&&hasPart(arr,"ツッコミ","スカシ")) add("名人芸","medium");
  // 掛け合い: ボケ/ツッコミ交互4連続
  (function(){
    let run=1;for(let i=1;i<arr.length;i++){
      const a=arr[i-1],b=arr[i];
      const ok=a&&b&&((a.kind==="ボケ"&&b.kind==="ツッコミ")||(a.kind==="ツッコミ"&&b.kind==="ボケ"));
      if(ok){run++;if(run>=4){add("掛け合い","medium");break;}}else run=1;
    }
  })();
  // 七変化: 異なる性質タグのボケ4種以上
  (function(){
    const tags=new Set(arr.filter(p=>p&&p.kind==="ボケ").map(p=>p.tag));
    if(tags.size>=4)add("七変化","medium");
  })();

  // ---- 役満(4) ----
  // 尻上がり: 威力が1→9で完全右肩上がり(全枠埋まり、厳密増加)
  (function(){
    if(arr.some(p=>!p))return;
    for(let i=1;i<arr.length;i++){if(arr[i].pow<=arr[i-1].pow)return;}
    add("尻上がり","yakuman");
  })();
  // 中間7枠が全部埋まっている前提の役満
  const midFull = mid.length===7;
  const inSet=(p,kind,tags)=>p&&p.kind===kind&&tags.includes(p.tag);
  if(midFull){
    // 本格しゃべくり: しゃべくり / フリ:日常or説明, ボケ:あるあるor誇張, ツッコミ:直球orノリ
    if(currentForm==="shab"&&mid.every(p=>
      inSet(p,"フリ",["日常","説明"])||inSet(p,"ボケ",["あるある","誇張"])||inSet(p,"ツッコミ",["直球","ノリ"])
    )) add("本格しゃべくり","yakuman");
    // 演技派コント: コント / フリ:説明or持論, ボケ:動きorあるある, ツッコミ:ノリorスカシ
    if(currentForm==="konto"&&mid.every(p=>
      inSet(p,"フリ",["説明","持論"])||inSet(p,"ボケ",["動き","あるある"])||inSet(p,"ツッコミ",["ノリ","スカシ"])
    )) add("演技派コント","yakuman");
    // 奇想天外: 形式問わず / フリ:妄想or持論, ボケ:ひねりor裏切り, ツッコミ:例えorスカシ
    if(mid.every(p=>
      inSet(p,"フリ",["妄想","持論"])||inSet(p,"ボケ",["ひねり","裏切り"])||inSet(p,"ツッコミ",["例え","スカシ"])
    )) add("奇想天外","yakuman");
  }

  return res;
}

/* ===========================================================
   手応え計算（威力合計 × コンボ倍率）
   ※SCORING: 小1.10/中1.25(局所・最上位) + 役満1.15(全体・両立)
   手応えはリズム・能力倍率を平均1.0と見た概算値として威力ベースで提示
   =========================================================== */
const MULT={small:1.10,medium:1.25,yakuman:1.15};
function calcTegotae(combos){
  const arr=getPlacedParts();
  // 各パーツに小・中の最上位倍率
  const localMult=arr.map(()=>1.0);
  // どのパーツがどのコンボに関与するかは簡略化し、
  // 「成立した小・中コンボの該当倍率を、関与パーツへmax適用」を近似実装する。
  // ここでは簡略化して、小・中は成立数に応じた局所倍率を主要パーツに割当てる近似ではなく、
  // 厳密な関与判定は重いので、デモでは下記方針:
  //   ・各パーツ素威力を合計
  //   ・成立した小/中コンボごとに「平均的な関与2.5パーツ×(倍率-1)×平均威力」を加算
  //   ・役満は全パーツに×1.15
  let base=0;arr.forEach(p=>{if(p)base+=p.pow;});
  if(base===0)return 0;
  const placedCount=arr.filter(p=>p).length;
  const avgPow=base/placedCount;

  let bonus=0;
  combos.forEach(c=>{
    if(c.rank==="small") bonus += avgPow*2.5*(MULT.small-1);   // 約2.5パーツ局所
    else if(c.rank==="medium") bonus += avgPow*3.5*(MULT.medium-1); // 約3.5パーツ局所
  });
  // 役満: 全体に×1.15（小中と両立=base+bonusに対して乗算的に上乗せ）
  const hasYaku=combos.some(c=>c.rank==="yakuman");
  let total=base+bonus;
  if(hasYaku) total = total*MULT.yakuman;

  // 上限99
  return Math.min(99, Math.round(total));
}

/* ===========================================================
   描画
   =========================================================== */
const lineupEl=document.getElementById("lineup");
const stockGridEl=document.getElementById("stockGrid");
const tegotaeValEl=document.getElementById("tegotaeVal");
const comboChipsEl=document.getElementById("comboChips");

let stockFilter="all";

function partCardHTML(p,opts={}){
  // 種別クラス（本体色）
  const typeCls = {
    "ツカミ":"t-tsukami","フリ":"t-furi","ボケ":"t-boke","ツッコミ":"t-tsukkomi","オチ":"t-ochi"
  }[p.kind] || "";
  // 形式クラス（威力バッジ色）
  const formCls = "f-"+p.form; // f-shab / f-konto / f-both
  const usedCls = opts.used ? "used" : "";
  return `<div class="part ${typeCls} ${formCls} ${usedCls}" data-pid="${p.id}">
    <span class="pw">${p.pow}</span>
    <span class="pmeta"><span class="ptag">${p.tag}</span><span class="ptype">${p.kind}</span></span>
    <span class="pgrip">⋮⋮</span>
  </div>`;
}

function renderLineup(){
  lineupEl.innerHTML="";
  SLOTS.forEach(s=>{
    const slot=document.createElement("div");
    slot.dataset.pos=s.pos;
    const pid=placement[s.pos];
    const p=pid?STOCK.find(x=>x.id===pid):null;
    if(p){
      // 配置済み: 番号 + パーツ を横一列に一体化（パワプロ方式・役割ラベルは省略）
      slot.className="slot filled"+(s.fixed?" fixed":"");
      slot.innerHTML=`
        <div class="batt">${s.pos}</div>
        <div class="slot-drop" data-pos="${s.pos}">${partCardHTML(p)}</div>`;
    }else{
      // 空き: 番号 + 役割ラベル + ヒント（2段）
      slot.className="slot empty"+(s.fixed?" fixed":"");
      slot.innerHTML=`
        <div class="slothead"><div class="batt">${s.pos}</div><div class="role">${s.role}</div></div>
        <div class="slot-drop" data-pos="${s.pos}">
          <span class="slot-empty-hint">${s.accept.join("・")}</span>
        </div>`;
    }
    lineupEl.appendChild(slot);
  });
  bindDnD();
}

function renderStock(){
  stockGridEl.innerHTML="";
  // 形式でフィルタ: both + 現在の形式
  const usedIds=new Set(Object.values(placements[currentForm]).filter(Boolean));
  const visible=STOCK.filter(p=>(p.form==="both"||p.form===currentForm));
  // 種別フィルタ
  const groups=["ツカミ","フリ","ボケ","ツッコミ","オチ"];
  groups.forEach(g=>{
    if(stockFilter!=="all"&&stockFilter!==g)return;
    const items=visible.filter(p=>p.kind===g);
    if(items.length===0)return;
    const lbl=document.createElement("div");
    lbl.className="seedlbl";lbl.textContent=g;
    stockGridEl.appendChild(lbl);
    items.forEach(p=>{
      const wrap=document.createElement("div");
      wrap.innerHTML=partCardHTML(p,{used:usedIds.has(p.id)});
      stockGridEl.appendChild(wrap.firstElementChild);
    });
  });
  bindDnD();
}

function refreshScore(){
  const combos=detectCombos();
  tegotaeValEl.textContent=calcTegotae(combos);
  // コンボチップ
  if(combos.length===0){
    comboChipsEl.innerHTML=`<span class="chip none">パーツを並べてコンボを狙え</span>`;
  }else{
    // 役満→中→小の順で表示
    const order={yakuman:0,medium:1,small:2};
    const rlabel={yakuman:"役満",medium:"中",small:"小"};
    combos.sort((a,b)=>order[a.rank]-order[b.rank]);
    comboChipsEl.innerHTML=combos.map(c=>
      `<span class="chip ${c.rank}"><span class="r">${rlabel[c.rank]}</span>${c.name}</span>`
    ).join("");
  }
}

/* ===========================================================
   ドラッグ＆ドロップ
   =========================================================== */
let dragPid=null;
let dragFrom=null; // {type:'stock'} or {type:'slot',pos}
let ghostEl=null;
let pointerActive=false;
let startX=0, startY=0, srcEl=null;
const DRAG_THRESHOLD=4; // 4px動いたら即ドラッグ開始（長押し不要）

// ドラッグゴースト要素を用意
function ensureGhost(){
  if(!ghostEl){
    ghostEl=document.createElement("div");
    ghostEl.id="dragGhost";
    document.body.appendChild(ghostEl);
  }
  return ghostEl;
}

function bindDnD(){
  document.querySelectorAll(".part").forEach(el=>{
    // pointerdownで即座に掴む準備（長押し待ちなし）
    el.addEventListener("pointerdown",e=>{
      if(e.button!==undefined && e.button!==0) return; // 左クリック/主ポインターのみ
      srcEl=el;
      startX=e.clientX; startY=e.clientY;
      const slotDrop=el.closest(".slot-drop");
      dragFrom=slotDrop?{type:"slot",pos:+slotDrop.dataset.pos}:{type:"stock"};
      dragPid=el.dataset.pid;
      pointerActive=false; // 閾値を超えるまではドラッグ開始しない
      // pointermove/up を document で監視
      document.addEventListener("pointermove",onPointerMove);
      document.addEventListener("pointerup",onPointerUp);
      // テキスト選択など抑止
      e.preventDefault();
    });
  });
}

function onPointerMove(e){
  if(!srcEl) return;
  if(!pointerActive){
    // 閾値を超えたらドラッグ開始
    if(Math.abs(e.clientX-startX)>DRAG_THRESHOLD || Math.abs(e.clientY-startY)>DRAG_THRESHOLD){
      beginDrag();
    }else{
      return;
    }
  }
  // ゴースト追従
  if(ghostEl){
    ghostEl.style.left=e.clientX+"px";
    ghostEl.style.top=e.clientY+"px";
  }
  // ドロップ先ハイライト
  updateHover(e.clientX,e.clientY);
}

function beginDrag(){
  pointerActive=true;
  document.body.classList.add("dragging-active");
  srcEl.classList.add("dragging");
  // ゴースト生成（掴んだカードの複製）
  const g=ensureGhost();
  const p=STOCK.find(x=>x.id===dragPid);
  g.innerHTML=partCardHTML(p);
  g.style.display="block";
}

let lastHoverSlot=null;
function updateHover(x,y){
  // 座標下の要素からスロットを特定
  const el=document.elementFromPoint(x,y);
  const slot=el?el.closest(".slot"):null;
  const overStock = el?el.closest(".stock"):null;
  // 既存ハイライト解除
  if(lastHoverSlot && lastHoverSlot!==slot){lastHoverSlot.classList.remove("drag-over");lastHoverSlot=null;}
  if(slot){
    const pos=+slot.dataset.pos;
    if(canDrop(pos)){slot.classList.add("drag-over");lastHoverSlot=slot;}
  }
}

function onPointerUp(e){
  document.removeEventListener("pointermove",onPointerMove);
  document.removeEventListener("pointerup",onPointerUp);
  if(pointerActive){
    // ドロップ判定
    const el=document.elementFromPoint(e.clientX,e.clientY);
    const slot=el?el.closest(".slot"):null;
    const overStock=el?el.closest(".stock"):null;
    if(slot){
      const pos=+slot.dataset.pos;
      if(canDrop(pos)) doDrop(pos);
    }else if(overStock && dragFrom && dragFrom.type==="slot"){
      // ストック領域へ戻す＝外す
      placements[currentForm][dragFrom.pos]=null;
      afterChange();
    }
  }
  // 後始末
  cleanupDrag();
}

function cleanupDrag(){
  if(srcEl) srcEl.classList.remove("dragging");
  document.body.classList.remove("dragging-active");
  if(lastHoverSlot){lastHoverSlot.classList.remove("drag-over");lastHoverSlot=null;}
  if(ghostEl){ghostEl.style.display="none";ghostEl.innerHTML="";}
  document.querySelectorAll(".slot.drag-over").forEach(s=>s.classList.remove("drag-over"));
  srcEl=null; pointerActive=false; dragPid=null; dragFrom=null;
}

// そのパーツをその枠に置けるか（種別の受け入れ判定）
function canDrop(pos){
  if(!dragPid)return false;
  const p=STOCK.find(x=>x.id===dragPid);
  const sdef=SLOTS.find(s=>s.pos===pos);
  if(!p||!sdef)return false;
  if(!(p.form==="both"||p.form===currentForm))return false;
  return sdef.accept.includes(p.kind);
}

function doDrop(pos){
  const p=STOCK.find(x=>x.id===dragPid);
  for(const k in placements[currentForm]){if(placements[currentForm][k]===dragPid)placements[currentForm][k]=null;}
  const existing=placements[currentForm][pos];
  if(dragFrom.type==="slot"&&existing){
    const fromDef=SLOTS.find(s=>s.pos===dragFrom.pos);
    const exP=STOCK.find(x=>x.id===existing);
    if(fromDef.accept.includes(exP.kind)&&(exP.form==="both"||exP.form===currentForm)){
      placements[currentForm][dragFrom.pos]=existing;
    }else{
      placements[currentForm][dragFrom.pos]=null;
    }
  }
  placements[currentForm][pos]=dragPid;
  afterChange();
}

function afterChange(){
  renderLineup();renderStock();refreshScore();
}

/* ===========================================================
   形式トグル & フィルタ
   =========================================================== */
const formSwitchEl=document.getElementById("formSwitch");
function updateSwitchUI(){
  formSwitchEl.classList.toggle("is-shab", currentForm==="shab");
  formSwitchEl.classList.toggle("is-konto", currentForm==="konto");
}
formSwitchEl.addEventListener("click",e=>{
  // タップでトグル（しゃべくり⇔コント）
  currentForm = (currentForm==="shab") ? "konto" : "shab";
  updateSwitchUI();
  // 配置はリセットしない（形式ごとに別打線を保持。表示を切り替えるだけ）。
  renderLineup();renderStock();refreshScore();
});

document.getElementById("filters").addEventListener("click",e=>{
  const btn=e.target.closest("button");if(!btn)return;
  stockFilter=btn.dataset.f;
  document.querySelectorAll("#filters button").forEach(b=>b.classList.remove("on"));
  btn.classList.add("on");
  renderStock();
});

/* ===== 初期描画 ===== */
renderLineup();
renderStock();
refreshScore();
