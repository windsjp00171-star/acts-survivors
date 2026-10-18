"""招式升級說明產生器：由 data/game.json 的 base＋levels 算出 Lv2～Lv5 的說明（傷害 +X%、範圍 +X%、攻擊速度 +X%……）。

用法：python3 tools/gen_skill_desc.py          只列出和現在不一樣的地方
      python3 tools/gen_skill_desc.py --write  寫回 game.json
改了招式的 levels 數值之後跑一次，說明就會跟著對。新能力（從 0 變成有）保留原本的文字；
特別的級數寫在 HAND。分支與進化的說明是手寫的，這支程式不會動。
"""
import os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import json,re,sys
g=json.load(open('data/game.json',encoding='utf-8'))
def n(v):
    v=round(float(v),2); return str(int(v)) if v==int(v) else str(v)
PCT={"radius":"範圍","max_radius":"範圍","spit_r":"範圍","save_r":"範圍","jump_range":"跳躍距離","range":"射程","length":"長度","height":"浪高","reach":"距離",
     "width":"寬度","thick":"粗細","size":"大小","knock":"擊退","knockback":"擊退","push":"推力","pull":"拉力","angle":"角度"}
CNT={"count":("數量",""),"pierce":("穿透","隻"),"jumps":("連跳","隻"),"split":("分裂","發"),"beams":("光束","道"),"rings":("圈數","圈"),"slams":("連砸","次"),
     "waves":("浪","波"),"pulses":("鼓聲","波"),"lions":("獅子","隻"),"pieces":("屏障","片"),"max":("最多","件"),"returns":("來回","次")}
SEC={"cooldown":"出手間隔","fire_every":"出手間隔","stun":"定住","confuse":"混亂","hold":"含在肚裡","life":"持續","save_cd":"救援間隔"}
MUL={"lies_mult":"對謊言傷害","elite_mult":"對菁英傷害","crit_mult":"會心傷害","linked_mult":"被連結觸發的威力","revive_speed":"扶起速度","attack_speed":"攻擊加快"}
PCTV={"crit":"會心機率","expose":"破綻（受到的傷害）","save_heal":"救援回血"}
ABS={"damage":"傷害","heal":"回血","amount":"回血","heal_comp":"同伴回血","shout":"喊聲傷害","combo_keep":"連鎖保留"}
NOUN={"bolt":("光箭","支"),"letter":("書信","封"),"sling":("石子","顆"),"fire":("火","道"),"coin":("錢幣","枚"),"glory":("光柱","道"),"pilum":("標槍","支"),
      "sew":("衣服","件"),"errand":("一次差遣","個"),"fig":("果子","顆"),"jars":("瓶子","個"),"fish":("一次吞","隻"),"medicine":("藥瓶","瓶"),"trumpet":("祭司","位")}
MAXU={"dawn":("最多","片"),"fig":("最多","棵"),"jars":("最多","個"),"sew":("每人最多疊","件")}
OVR={("prayer","slams"):("連禱","次"),("sea","beams"):("水道","道"),("lamp","beams"):("光","道"),("street","beams"):("光","道"),("coin","split"):("分散成","枚")}
SK=[None]
def part(k,a,b):
    sk=SK[0]
    if k=="count" and sk in NOUN and a not in (None,0): return "%s %s → %s %s"%(NOUN[sk][0],n(a),n(b),NOUN[sk][1])
    if k=="max" and sk in MAXU: return "%s %s → %s %s"%(MAXU[sk][0],n(a),n(b),MAXU[sk][1])
    if (sk,k) in OVR and a not in (None,0): return "%s %s → %s %s"%(OVR[(sk,k)][0],n(a),n(b),OVR[(sk,k)][1])
    if k=="height" and sk=="flood": return "寬度 +%d%%"%round((b/a-1)*100)
    if k=="combo_keep": return "連鎖撐得更久 %s → %s 秒"%(n(a),n(b))
    if k=="expose" and a: return "%s的敵人受到的傷害 +%d%% → +%d%%"%("被標記" if sk=="decree" else "被照到",round(a*100),round(b*100))
    if a is not None and float(a)==float(b): return ""
    if a in (None,0,0.0): return None   # 新能力：用原本的文字
    if k in PCT:
        p=round((b/a-1)*100); return "%s %s%d%%"%(PCT[k],"+" if p>=0 else "",p)
    if k in CNT: return ("%s %s → %s %s"%(CNT[k][0],n(a),n(b),CNT[k][1])).rstrip()
    if k in ("damage","heal","amount","heal_comp","shout"):
        p=round((b/a-1)*100); return "%s %s%d%%"%(ABS[k],"+" if p>=0 else "",p)
    if k in SEC:
        if k in ("cooldown","fire_every","save_cd"): return "%s %s → %s 秒（更頻繁）"%(SEC[k],n(a),n(b)) if b<a else "%s %s → %s 秒"%(SEC[k],n(a),n(b))
        return "%s %s → %s 秒"%(SEC[k],n(a),n(b))
    if k=="attack_speed": return "攻擊加快 +%d%% → +%d%%"%(round((a-1)*100),round((b-1)*100))
    if k in MUL: return "%s ×%s → ×%s"%(MUL[k],n(a),n(b))
    if k in PCTV: return "%s %d%% → %d%%"%(PCTV[k],round(a*100),round(b*100))
    if k in ABS: return "%s %s → %s"%(ABS[k],n(a or 0),n(b))
    return None
out={}
for key,s in g['skills'].items():
    SK[0]=key
    cur=dict(s['base']); new=[s['desc'][0]]
    for i,lv in enumerate(s.get('levels',[])):
        parts=[]; flag=False
        for k,v in lv.items():
            p=part(k,cur.get(k),v)
            if p is None: flag=True
            elif p: parts.append(p)
            cur[k]=v
        old=s['desc'][i+1]
        ref=re.search(r"（[^（）]*\d+:\d+[^（）]*）$",old)
        txt="、".join(parts)
        if flag or not parts:
            base_old=(old[:ref.start()] if ref else old).split("；")[0]
            txt=base_old+("；"+txt if parts else "")
        if ref and ref.group(0) not in txt: txt+=ref.group(0)
        new.append(txt)
    out[key]=new
HAND={("bolt",4):"可以穿透 2 隻敵人；大小 +100%、傷害 +100%",("ring",4):"打中的敵人暈眩 0.8 秒；範圍 +25%、擊退 +33%",
      ("aura",4):"光環裡的同伴不會被懼怕嚇散；範圍 +25%",("bring",4):"順便幫主角回 6 血；範圍 +42%（約 1:41）"}
for (k,i),v in HAND.items(): out[k][i]=v
import re as _re
def _speed(m):
    a,b=float(m.group(2)),float(m.group(3)); lab={"出手間隔":"攻擊速度","治療間隔":"治療速度"}.get(m.group(1),m.group(1))
    return "%s +%d%%"%(lab,round((a/b-1)*100))
for key in out:
    for i in range(1,len(out[key])):
        t=_re.sub(r"(出手間隔|治療間隔) ([\d.]+) → ([\d.]+) 秒（更頻繁）",_speed,out[key][i])
        t=_re.sub(r"救援間隔 ([\d.]+) → ([\d.]+) 秒（更頻繁）",r"救援更常發動：每 \1 → \2 秒一次",t)
        if key=="heal": t=t.replace("攻擊速度","治療速度")
        out[key][i]=t
if __name__=="__main__":
    import sys
    p="data/game.json"; text=open(p,encoding="utf-8").read(); n=0
    start=text.index('"skills"')
    for key,s in g['skills'].items():
        i0=text.index('"%s": {'%key,start)
        for i in range(1,len(s['desc'])):
            if s['desc'][i]!=out[key][i]:
                n+=1; print("%s Lv%d：%s\n      → %s"%(key,i+1,s['desc'][i],out[key][i]))
                old=json.dumps(s['desc'][i],ensure_ascii=False); j=text.index(old,i0)
                text=text[:j]+json.dumps(out[key][i],ensure_ascii=False)+text[j+len(old):]
    if "--write" in sys.argv and n:
        json.loads(text); open(p,"w",encoding="utf-8").write(text)
    print("不一樣的：%d 條%s"%(n,"（已寫回）" if "--write" in sys.argv and n else ""))
