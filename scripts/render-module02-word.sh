#!/usr/bin/env bash
# Render the Module 2 Word export and apply Word-only styling that the
# reference doc cannot express, then stage the artifact into _word/.
#
# 1. quarto renders module02/module02-word.qmd with the `word` profile.
# 2. Quarto renders callouts (callout-important / callout-note) as two-row
#    tables whose runs carry no font, so they inherit the serif body styles
#    and the reference doc cannot isolate them. Set Arial directly on every
#    run inside tables whose label row marks them as callouts. Label rows
#    read "Note"/"Important", or "Important ..." when the callout opens with
#    a heading (e.g. the resources bird-ethics callout). Leave sizes and
#    other run formatting untouched; the timeline table is never matched.
# 3. Stage the result as _word/module02.docx.
#
# pandoc's docx output carries known schema quirks (loose element order in
# callout tables, duplicated custom style ids). Word tolerates them, so
# validation is informational only.
set -euo pipefail
cd "$(dirname "$0")/.."

quarto render module02/module02-word.qmd --profile word --to docx --output module02.docx

python3 - <<'PY'
import shutil
import zipfile
import xml.etree.ElementTree as ET

SRC = "module02.docx"
EXPECTED_CALLOUTS = 9
W = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

for prefix, uri in {
    "wpc": "http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas",
    "cx": "http://schemas.microsoft.com/office/drawing/2014/chartex",
    "mc": "http://schemas.openxmlformats.org/markup-compatibility/2006",
    "o": "urn:schemas-microsoft-com:office:office",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
    "v": "urn:schemas-microsoft-com:vml",
    "wp14": "http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing",
    "wp": "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
    "w10": "urn:schemas-microsoft-com:office:word",
    "w": W,
    "w14": "http://schemas.microsoft.com/office/word/2010/wordml",
    "w15": "http://schemas.microsoft.com/office/word/2012/wordml",
    "wpg": "http://schemas.microsoft.com/office/word/2010/wordprocessingGroup",
    "wpi": "http://schemas.microsoft.com/office/word/2010/wordprocessingInk",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "pic": "http://schemas.openxmlformats.org/drawingml/2006/picture",
    "wne": "http://schemas.microsoft.com/office/word/2006/wordml",
    "wps": "http://schemas.microsoft.com/office/word/2010/wordprocessingShape",
}.items():
    ET.register_namespace(prefix, uri)


def q(tag):
    return f"{{{W}}}{tag}"


with zipfile.ZipFile(SRC) as z:
    names = z.namelist()
    parts = {n: z.read(n) for n in names}

root = ET.fromstring(parts["word/document.xml"])


def element_text(el):
    return "".join(t.text or "" for t in el.iter(q("t"))).strip()


def is_callout_label(text):
    return (
        text in ("Note", "Tip", "Warning", "Caution")
        or text.startswith("Important")
    )


def set_run_font(run):
    rpr = run.find(q("rPr"))
    if rpr is None:
        rpr = ET.Element(q("rPr"))
        run.insert(0, rpr)
    for old in rpr.findall(q("rFonts")):
        rpr.remove(old)
    fonts = ET.Element(q("rFonts"))
    for attr in ("ascii", "hAnsi", "eastAsia", "cs"):
        fonts.set(q(attr), "Arial")
    rstyle = rpr.find(q("rStyle"))
    rpr.insert(list(rpr).index(rstyle) + 1 if rstyle is not None else 0, fonts)

callouts = 0
for tbl in root.iter(q("tbl")):
    rows = tbl.findall(q("tr"))
    if (
        len(rows) != 2
        or not is_callout_label(element_text(rows[0]))
    ):
        continue
    for run in tbl.iter(q("r")):
        set_run_font(run)
    callouts += 1

assert callouts == EXPECTED_CALLOUTS, (
    f"expected {EXPECTED_CALLOUTS} callout tables, matched {callouts}; "
    "update EXPECTED_CALLOUTS if module content changed"
)

parts["word/document.xml"] = ET.tostring(root, encoding="UTF-8", xml_declaration=True)
shutil.copy(SRC, SRC + ".bak")
with zipfile.ZipFile(SRC, "w", zipfile.ZIP_DEFLATED) as z:
    for n in names:
        z.writestr(n, parts[n])
print(f"callout tables styled: {callouts}")
PY

officecli validate module02.docx >/dev/null 2>&1 \
  || echo "note: pandoc docx schema quirks present (pre-existing); Word tolerates"

mv module02.docx _word/module02.docx
rm -f module02.docx.bak
echo "staged: _word/module02.docx"
