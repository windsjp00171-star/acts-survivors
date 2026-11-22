"""用 LPC（Liberated Pixel Cup）開源部件拼出每一位人物的走路圖。

用法：
  python tools/make_people_lpc.py --from <LPC 儲存庫資料夾>   第一次：把用到的部件、調色盤、作者資料抄進 tools/lpc_src 再產生
  python tools/make_people_lpc.py                             之後：只用 tools/lpc_src 重新產生
輸出：assets/sprites/lpc/<key>.png、<key>_evo.png（576×256：9 格 × 上、左、下、右，每格 64×64；第 0 格是站姿）
      data/credits_lpc.json（遊戲內作者名單用）

授權：每一個部件都必須提供 OGA-BY 或 CC0（允許放在有 DRM 的平台、不要求相同方式分享），否則直接停下來。
"""
import csv
import json
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "tools" / "lpc_src"
OUT = ROOT / "assets" / "sprites" / "lpc"
CELL, COLS, ROWS = 64, 9, 4
UP, LEFT, DOWN, RIGHT = range(4)
OK_LICENSES = ("OGA-BY", "CC0")

# 部件 id（sheet_definitions 的檔名）
HAIR = {"bald": "hair_balding", "curly2": "hair_curly_short2", "buzz": "hair_buzzcut", "page": "hair_page",
        "plain": "hair_plain", "long": "hair_long_center_part", "wavy": "hair_wavy",
        "straight": "hair_long_straight", "wild": "hair_jewfro"}
BEARD = {"medium": "beards_medium", "trim": "beards_trimmed", "full": "beards_winter"}
HAT = {"hijab": "hat_hood_hijab", "hood": "hat_hood_cloth", "legion": "hat_helmet_legion", "band": "hat_headband_thick"}

# 每人一行：性別、膚色、髮型/髮色、鬍子/鬍色、上衣色、裙（袍）色、腰帶色、其他
M, F = "male", "female"
PEOPLE = {
    "paul": (M, "olive", "bald/dark_gray", "medium/dark_gray", "brown", "brown", "tan", {"staff": 1}),
    "peter": (M, "olive", "curly2/dark_brown", "full/dark_brown", "bluegray", "bluegray", "brown", {}),
    "stephen": (M, "olive", "plain/black", "", "white", "white", "yellow", {}),
    "john": (M, "olive", "wavy/chestnut", "", "white", "white", "blue", {}),
    "tim": (M, "olive", "page/dark_brown", "", "forest", "forest", "tan", {}),
    "philip": (M, "olive", "curly2/black", "trim/black", "tan", "tan", "maroon", {"cape": "orange"}),
    "lydia": (F, "olive", "", "", "purple", "purple", "yellow", {"hat": "hijab/lavender"}),
    "maxwell": (M, "light", "plain/ginger", "full/ginger", "charcoal", "", "", {"pants": "black", "shoes": "boots"}),
    "asaph": (M, "olive", "long/gray", "full/gray", "sky", "sky", "yellow", {"hat": "band/yellow"}),
    "barn": (M, "olive", "plain/chestnut", "full/chestnut", "orange", "orange", "brown", {}),
    "luke": (M, "olive", "page/dark_brown", "trim/dark_brown", "teal", "teal", "white", {}),
    "silas": (M, "olive", "wild/black", "medium/black", "maroon", "maroon", "yellow", {}),
    "apollos": (M, "bronze", "curly2/black", "medium/black", "slate", "slate", "yellow", {"cape": "white"}),
    "pri": (F, "olive", "", "", "rose", "rose", "brown", {"hat": "hijab/tan"}),
    "aq": (M, "olive", "plain/dark_brown", "medium/dark_brown", "leather", "leather", "tan", {}),
    "david": (M, "olive", "curly2/redhead", "", "tan", "tan", "red", {"cape": "purple"}),
    "samson": (M, "bronze", "long/black", "full/black", "red", "red", "leather", {}),
    "moses": (M, "olive", "long/white", "full/white", "red", "tan", "brown", {"staff": 1}),
    "elijah": (M, "olive", "wild/gray", "full/gray", "walnut", "walnut", "leather", {"staff": 1, "cape": "brown"}),
    "joshua": (M, "bronze", "plain/black", "trim/black", "blue", "brown", "leather", {"hat": "band/red"}),
    "thomas": (M, "olive", "page/dark_brown", "trim/dark_brown", "gray", "gray", "navy", {}),
    "matthew": (M, "olive", "plain/black", "medium/black", "green", "green", "yellow", {}),
    "andrew": (M, "olive", "curly2/light_brown", "medium/light_brown", "forest", "tan", "brown", {}),
    "cornelius": (M, "light", "buzz/dark_brown", "", "red", "red", "leather", {"hat": "legion/bronze", "cape": "red"}),
    "dorcas": (F, "olive", "", "", "orange", "orange", "white", {"hat": "hijab/white"}),
    "mark": (M, "olive", "page/chestnut", "", "yellow", "tan", "blue", {}),
    "james": (M, "olive", "wavy/black", "full/black", "purple", "purple", "tan", {"staff": 1}),
    "mary": (F, "olive", "", "", "pink", "pink", "yellow", {"hat": "hijab/rose"}),
    "zacchaeus": (M, "olive", "bald/dark_brown", "trim/dark_brown", "green", "purple", "yellow", {}),
    "nicodemus": (M, "olive", "plain/gray", "full/gray", "navy", "navy", "white", {"hat": "hood/navy"}),
    "gideon": (M, "bronze", "curly2/dark_brown", "medium/dark_brown", "tan", "brown", "red", {}),
    "daniel": (M, "olive", "wavy/black", "trim/black", "blue", "blue", "yellow", {"cape": "navy"}),
    "jonah": (M, "olive", "wild/dark_brown", "medium/dark_brown", "teal", "gray", "walnut", {}),
    "noah": (M, "olive", "bald/white", "full/white", "walnut", "leather", "tan", {}),
    "esther": (F, "olive", "wavy/black", "", "purple", "purple", "yellow", {"cape": "lavender"}),
    "miriam": (F, "olive", "", "", "teal", "teal", "orange", {"hat": "hijab/red"}),
    "heman": (M, "olive", "page/gray", "medium/gray", "white", "sky", "navy", {}),
    "jeduthun": (M, "olive", "straight/chestnut", "medium/chestnut", "lavender", "lavender", "white", {}),
    "bunsui": (M, "amber", "buzz/black", "", "charcoal", "charcoal", "", {"shoes": "boots"}),
    "kauchang": (M, "amber", "plain/black", "", "navy", "", "", {"pants": "gray", "shoes": "boots"}),
    "ananias": (M, "olive", "plain/gray", "medium/gray", "sky", "sky", "tan", {}),
    "disciple": (M, "olive", "curly2/dark_brown", "", "tan", "tan", "brown", {}),
    "jesus": (M, "olive", "wavy/dark_brown", "medium/dark_brown", "white", "white", "red", {}),
}


class Lpc:
    """讀部件：sheet_definitions 查圖檔路徑，palette_definitions 換色，並記下用過的檔案。"""

    def __init__(self, base: Path, copy_to: Path | None) -> None:
        self.base, self.copy_to, self.used = base, copy_to, {}   # used：圖檔 → 定義檔裡的作者資料
        self.defs = {p.stem: p for p in (base / "sheet_definitions").rglob("*.json")}
        self.pal = {}
        for mat in ("body", "cloth", "hair", "eye", "metal"):
            meta = json.loads((base / f"palette_definitions/{mat}/meta_{mat}.json").read_text("utf-8"))
            colors = json.loads((base / f"palette_definitions/{mat}/{mat}_ulpc.json").read_text("utf-8"))
            self.pal[mat] = (colors, meta["base"])
            self._keep(f"palette_definitions/{mat}/meta_{mat}.json")
            self._keep(f"palette_definitions/{mat}/{mat}_ulpc.json")

    def _keep(self, rel: str) -> None:
        if self.copy_to:
            dst = self.copy_to / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(self.base / rel, dst)

    def recolor(self, im: Image.Image, mat: str, name: str) -> Image.Image:
        colors, base = self.pal[mat]
        rgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))  # noqa: E731
        table = {rgb(a): rgb(b) for a, b in zip(colors[base], colors[name])}
        out = im.copy()
        px = out.load()
        for y in range(out.height):
            for x in range(out.width):
                r, g, b, a = px[x, y]
                if a and (r, g, b) in table:
                    px[x, y] = (*table[(r, g, b)], a)
        return out

    def layers(self, part: str, sex: str, color: str, eyes: str = "") -> list[tuple[int, Image.Image]]:
        path = self.defs[part]
        d = json.loads(path.read_text("utf-8"))
        self._keep(path.relative_to(self.base).as_posix())
        out = []
        for key in sorted(k for k in d if k.startswith("layer_")):
            folder = d[key].get(sex, "").replace("${head}", sex)
            if not folder:
                continue
            rel = f"spritesheets/{folder}walk.png"
            variant = f"spritesheets/{folder}walk/{color}.png"
            fixed = (self.base / variant).exists() and not d.get("recolors")
            rel = variant if fixed else rel
            im = Image.open(self.base / rel).convert("RGBA")
            assert im.size == (CELL * COLS, CELL * ROWS), (rel, im.size)
            self.used[f"{folder}walk.png"] = [c for c in d["credits"] if folder.startswith(c["file"].rstrip("/"))]
            self._keep(rel)
            rc = d.get("recolors")
            if rc and not fixed:
                mats = [rc] if "material" in rc else list(rc.values())
                for m in mats:
                    im = self.recolor(im, m["material"], eyes if m["material"] == "eye" else color)
            out.append((int(d[key]["zPos"]), im))
        assert out, f"{part} 沒有 {sex} 的圖"
        return out


def staff_layer() -> Image.Image:
    """手杖：自己畫的一根木棍（LPC 的手杖只有相同方式分享的授權，不用）。"""
    im = Image.new("RGBA", (CELL * COLS, CELL * ROWS))
    d = ImageDraw.Draw(im)
    for row, x in ((UP, 18), (LEFT, 22), (DOWN, 45), (RIGHT, 41)):
        for c in range(COLS):
            dx = 0 if c == 0 else (1 if c in (2, 3, 4) else -1 if c in (6, 7, 8) else 0)
            ox, oy = c * CELL + x + dx, row * CELL
            d.rectangle([ox - 1, oy + 25, ox + 2, oy + 61], fill=(38, 22, 14, 255))
            d.rectangle([ox, oy + 26, ox + 1, oy + 60], fill=(122, 80, 44, 255))
            d.line([ox, oy + 26, ox, oy + 60], fill=(160, 112, 64, 255))
    return im


def halo(im: Image.Image) -> Image.Image:
    """進化版：頭上一圈光環。"""
    out = im.copy()
    d = ImageDraw.Draw(out)
    for row in range(ROWS):
        for c in range(COLS):
            x, y = c * CELL + 32, row * CELL + (9 if c in (0, 1, 5) else 8)
            d.ellipse([x - 9, y - 3, x + 8, y + 2], outline=(120, 72, 10, 255), width=3)
            d.ellipse([x - 8, y - 2, x + 7, y + 1], outline=(255, 215, 94, 255), width=1)
    return out


def build(lpc: Lpc, key: str, evo: bool) -> Image.Image:
    sex, skin, hair, beard, top, skirt, sash, ex = PEOPLE[key]
    parts = lpc.layers("body", sex, skin) + lpc.layers(f"heads_human_{sex}", sex, skin, "brown") + lpc.layers("face_neutral", sex, skin, "brown")
    if hair:
        style, col = hair.split("/")
        parts += lpc.layers(HAIR[style], sex, col) + lpc.layers("eyebrows_thin", sex, col)
    if beard:
        style, col = beard.split("/")
        parts += lpc.layers(BEARD[style], sex, col)
    parts += lpc.layers("torso_clothes_longsleeve", sex, top)
    if skirt:
        parts += lpc.layers("legs_skirts_plain" if sex == M else "legs_skirt_straight", sex, skirt)
    if ex.get("pants"):
        parts += lpc.layers("legs_pants", sex, ex["pants"])
    if sash:
        parts += lpc.layers("belt_sash_narrow", sex, "yellow" if evo else sash)
    if ex.get("hat"):
        style, col = ex["hat"].split("/")
        parts += lpc.layers(HAT[style], sex, col)
    if ex.get("cape"):
        parts += lpc.layers("cape_solid", sex, ex["cape"])
    parts += lpc.layers("feet_boots_basic" if ex.get("shoes") == "boots" else "feet_sandals", sex, "brown")
    if ex.get("staff"):
        parts.append((140, staff_layer()))
    sheet = Image.new("RGBA", (CELL * COLS, CELL * ROWS))
    for _, im in sorted(parts, key=lambda p: p[0]):
        sheet.alpha_composite(im)
    return halo(sheet) if evo else sheet


def credits(base: Path, used: dict[str, list]) -> list[dict]:
    rows = {r["filename"].strip(): r for r in csv.DictReader((base / "CREDITS.csv").open(encoding="utf-8"), skipinitialspace=True)}
    out = []
    for f in sorted(used):
        r = rows.get(f)
        if r:
            authors, lic, urls = r["authors"].strip(), r["licenses"].strip(), r["urls"].strip()
        else:   # 總表沒列到的檔案：用部件定義檔裡寫的
            assert used[f], f"找不到 {f} 的作者資料"
            authors, lic, urls = (",".join(sorted({x for c in used[f] for x in c[k]})) for k in ("authors", "licenses", "urls"))
        assert any(k in lic for k in OK_LICENSES), f"{f} 的授權只有 {lic}，不用"
        out.append({"file": f, "authors": authors, "licenses": lic, "urls": urls})
    return out


def main() -> None:
    first = "--from" in sys.argv
    base = Path(sys.argv[sys.argv.index("--from") + 1]) if first else SRC
    lpc = Lpc(base, SRC if first else None)
    OUT.mkdir(parents=True, exist_ok=True)
    for key in PEOPLE:
        build(lpc, key, False).save(OUT / f"{key}.png", optimize=True)
        build(lpc, key, True).save(OUT / f"{key}_evo.png", optimize=True)
    rows = credits(base, lpc.used)
    authors = sorted({a.strip() for r in rows for a in r["authors"].split(",") if a.strip()}, key=str.lower)
    doc = {"_說明": "人物部件的作者名單（tools/make_people_lpc.py 產生）。OGA-BY 3.0 要求列出作者；遊戲內「日誌」頁底下顯示。",
           "source": "https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator",
           "license": "OGA-BY 3.0", "authors": authors, "files": rows}
    (ROOT / "data" / "credits_lpc.json").write_text(json.dumps(doc, ensure_ascii=False, indent=1), encoding="utf-8")
    if first:
        keep = {r["file"] for r in rows}
        src = list(csv.reader((base / "CREDITS.csv").open(encoding="utf-8"), skipinitialspace=True))
        with (SRC / "CREDITS.csv").open("w", encoding="utf-8", newline="") as fh:
            csv.writer(fh).writerows([src[0]] + [r for r in src[1:] if r and r[0].strip() in keep])
        (SRC / ".gdignore").touch()
    print(len(PEOPLE), "people,", len(rows), "parts,", len(authors), "authors")


if __name__ == "__main__":
    main()
