"""Render actual menu compose commands offline, without game attachment or settings writes.

Use a non-Store Python interpreter with Pillow. Source roots can point at a
preserved baseline; output must stay inside this repository's named review folder.
The HTML gallery compares all prefixes already exported into the same directory.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont

from runtime_guard import require_physical_runtime

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT / "dist" / "ui-refresh-review"
LUA_DLL = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Helldivers 2\bin\lua51.dll")


def lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def compose(source: Path, dll_path: Path, width: int, height: int) -> dict:
    """Run only the isolated Lua fixture and return its in-memory JSON global."""
    dll = ctypes.CDLL(str(dll_path))
    pointer = ctypes.c_void_p
    dll.luaL_newstate.restype = pointer
    dll.luaL_openlibs.argtypes = [pointer]
    dll.luaL_loadbuffer.argtypes = [pointer, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
    dll.luaL_loadbuffer.restype = ctypes.c_int
    dll.lua_pcall.argtypes = [pointer, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    dll.lua_pcall.restype = ctypes.c_int
    dll.lua_getfield.argtypes = [pointer, ctypes.c_int, ctypes.c_char_p]
    dll.lua_tolstring.argtypes = [pointer, ctypes.c_int, ctypes.c_void_p]
    dll.lua_tolstring.restype = ctypes.c_char_p
    dll.lua_close.argtypes = [pointer]
    state = dll.luaL_newstate()
    if not state:
        raise RuntimeError("Could not create an isolated Lua state")
    try:
        dll.luaL_openlibs(state)
        code = (
            "UI_PREVIEW_OPTIONS={source_root=" + lua_string(str(source)) +
            f",width={width},height={height}}}\n" +
            "dofile(" + lua_string(str(ROOT / "tests" / "ui_preview_fixture.lua")) + ")"
        ).encode("utf-8")
        status = dll.luaL_loadbuffer(state, code, len(code), b"@ui_preview")
        if not status:
            status = dll.lua_pcall(state, 0, 0, 0)
        if status:
            message = dll.lua_tolstring(state, -1, None)
            raise RuntimeError(message.decode("utf-8", errors="replace") if message else f"Lua error {status}")
        dll.lua_getfield(state, -10002, b"UI_PREVIEW_JSON")  # Lua 5.1 global environment.
        result = dll.lua_tolstring(state, -1, None)
        if not result:
            raise RuntimeError("Fixture did not export UI_PREVIEW_JSON")
        return json.loads(result.decode("utf-8"))
    finally:
        dll.lua_close(state)


class Fonts:
    def __init__(self, requested: Path | None):
        candidates = [requested] if requested else []
        candidates += [Path(r"C:\Windows\Fonts\arial.ttf"), Path(r"C:\Windows\Fonts\bahnschrift.ttf")]
        self.path = next((p for p in candidates if p and p.is_file()), None)
        self.cache: dict[int, ImageFont.FreeTypeFont | ImageFont.ImageFont] = {}

    def get(self, size: float):
        pixels = max(1, round(size))
        if pixels not in self.cache:
            self.cache[pixels] = ImageFont.truetype(str(self.path), pixels) if self.path else ImageFont.load_default(size=pixels)
        return self.cache[pixels]


def render(commands: list[dict], width: int, height: int, fonts: Fonts) -> Image.Image:
    """Match view.lua planes and order, with bottom-left coordinates and RGBA."""
    canvas = Image.new("RGBA", (width, height), (9, 13, 17, 255))
    ordered = sorted(enumerate(commands), key=lambda item: ((item[1].get("layer", 100) + (1 if item[1]["type"] == "text" else 0)), item[0]))
    for _, command in ordered:
        kind = command["type"]
        if kind not in {"rect", "text"}:
            raise ValueError(f"Unsupported compose primitive: {kind}")
        color = tuple(max(0, min(255, round(float(v)))) for v in command["c"])
        alpha = max(0, min(255, round(command.get("a", 1) * 255)))
        fill = color + (alpha,)
        x, y = float(command["x"]), float(command["y"])
        overlay = Image.new("RGBA", canvas.size)
        draw = ImageDraw.Draw(overlay)
        if kind == "rect":
            w, h = float(command["w"]), float(command["h"])
            if w <= 0 or h <= 0:
                continue
            draw.rectangle((x, height-y-h, x+max(0,w-1), height-y-h+max(0,h-1)), fill=fill)
        else:
            # Native Stingray glyph metrics/materials differ; baseline is approximate.
            draw.text((x, height-y), str(command["text"]), font=fonts.get(command.get("size", 20)), fill=fill, anchor="ls")
        canvas = Image.alpha_composite(canvas, overlay)
    draw = ImageDraw.Draw(canvas)
    draw.text((20, height-18), "OFFLINE COMPOSE PREVIEW  |  Representative controls  |  Approximate fonts; live game rendering unverified", font=fonts.get(15), fill=(155, 167, 175, 255), anchor="ls")
    return canvas.convert("RGB")


def gallery(output: Path) -> None:
    manifests = []
    for path in sorted(output.glob("*-manifest.json")):
        record = json.loads(path.read_text(encoding="utf-8"))
        manifests.append(record)
    payload = json.dumps(manifests, ensure_ascii=False).replace("<", "\\u003c")
    document = """<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>MCM UI refresh review</title><style>
*{box-sizing:border-box}body{margin:0;background:#10151a;color:#e3e9ed;font:15px Arial,sans-serif}header{padding:24px 28px;border-bottom:1px solid #34414b}h1{font-size:24px;font-weight:600;margin:0 0 9px}p{color:#a4b2bc;margin:0;line-height:1.5}nav{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}button{background:#24313b;color:#e3e9ed;border:1px solid #42525e;border-radius:4px;padding:9px 15px;cursor:pointer}button.active{background:#e9c656;color:#17202a;border-color:#e9c656}main{padding:24px;display:grid;grid-template-columns:repeat(auto-fit,minmax(min(650px,100%),1fr));gap:24px}article{min-width:0}h2{margin:0 0 10px;font-size:16px}img{display:block;width:100%;border:1px solid #384651}small{display:block;color:#a4b2bc;line-height:1.5;margin-top:8px}a{color:#9fe1e6}footer{padding:0 24px 24px;color:#a4b2bc}
</style><header><h1>MCM UI refresh review</h1><p>Actual menu.lua compose commands with the same offline demo registrations. Fonts and text baselines are approximate.<br>This previews layout and color only; native rendering, input ownership and live game behavior still need validation.</p><nav id="states"></nav></header><main id="frames"></main><footer>Open a frame for full-resolution inspection. JSON exports retain every draw command.</footer>
<script>const records=__RECORDS__;const labels=new Map;for(const r of records)for(const s of r.states)labels.set(s.id,s.label);const nav=document.getElementById('states'),frames=document.getElementById('frames');function show(id){for(const b of nav.children)b.classList.toggle('active',b.dataset.id===id);frames.replaceChildren();for(const r of records){const s=r.states.find(s=>s.id===id);if(!s)continue;const article=document.createElement('article'),title=document.createElement('h2'),link=document.createElement('a'),img=document.createElement('img'),note=document.createElement('small');title.textContent=r.prefix+' · '+s.label;link.href=s.image;img.src=s.image;img.alt=title.textContent;link.append(img);note.textContent=s.commands+' commands · '+r.width+' × '+r.height+' · '+r.font+' approximation · menu.lua '+r.menu_sha256.slice(0,12);article.append(title,link,note);frames.append(article)}}for(const [id,label]of labels){const b=document.createElement('button');b.dataset.id=id;b.textContent=label;b.onclick=()=>show(id);nav.append(b)}if(labels.size)show(labels.keys().next().value);</script></html>
""".replace("__RECORDS__", payload)
    (output / "index.html").write_text(document, encoding="utf-8")


def main() -> None:
    require_physical_runtime()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", type=Path, default=ROOT, help="Current maintained source or preserved baseline root")
    parser.add_argument("--output", type=Path, required=True, help="Explicit review directory inside dist/ui-refresh-review")
    parser.add_argument("--prefix", default="current", help="Short label; multiple prefixes become comparison columns")
    parser.add_argument("--lua-dll", type=Path, default=LUA_DLL)
    parser.add_argument("--font", type=Path, help="Optional local font; Windows Arial/Bahnschrift are the defaults")
    parser.add_argument("--width", type=int, default=1920)
    parser.add_argument("--height", type=int, default=1080)
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,39}", args.prefix):
        parser.error("--prefix must use letters, numbers, underscores or hyphens")
    if not (320 <= args.width <= 7680 and 240 <= args.height <= 4320):
        parser.error("Use a viewport from 320x240 through 7680x4320")
    source, output = args.source_root.resolve(), args.output.resolve()
    if not output.is_relative_to(REVIEW.resolve()):
        parser.error("--output must be inside this repository's dist/ui-refresh-review")
    for name in ("core", "menu", "grouping"):
        if not (source / "src" / f"{name}.lua").is_file():
            parser.error(f"Missing source module: {name}.lua")
    if not args.lua_dll.is_file():
        parser.error("The offline Lua 5.1 DLL was not found; supply --lua-dll")
    source_files = {str(path.relative_to(source / 'src')): path for path in (source / 'src').rglob('*.lua')}
    hashes = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in source_files.items()}
    result = compose(source, args.lua_dll, args.width, args.height)
    if any(hashlib.sha256(path.read_bytes()).hexdigest() != hashes[name] for name, path in source_files.items()):
        raise RuntimeError("Source changed while composing the preview; rerun after the edit completes")
    fonts = Fonts(args.font)
    output.mkdir(parents=True, exist_ok=True)
    (output / f"{args.prefix}-commands.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest = {"prefix": args.prefix, "width": args.width, "height": args.height, "font": fonts.path.name if fonts.path else "Pillow default", "menu_sha256": hashes["menu.lua"], "source_sha256": hashes, "offline": True, "approximate_fonts": True, "states": []}
    for state in result["states"]:
        filename = f"{args.prefix}-{state['id']}.png"
        render(state["commands"], args.width, args.height, fonts).save(output / filename)
        manifest["states"].append({"id": state["id"], "label": state["label"], "image": filename, "commands": len(state["commands"])})
    (output / f"{args.prefix}-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    gallery(output)
    print(f"Exported {len(result['states'])} offline states from {source}")
    print(output / "index.html")


if __name__ == "__main__":
    main()
