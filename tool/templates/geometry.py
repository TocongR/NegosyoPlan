"""Measure where each blank and box sits on the official forms.

Output (for the app's on-phone preview):
  out/geo/<form>-<n>.png      blank page pictures (the template with nothing filled in)
  out/geo/forms_layout.json   for each form: page sizes, blank boxes and check-box boxes, in PDF points
"""
import json, os, re, subprocess, sys, zipfile
import pdfplumber
from fill import fill

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out', 'geo')
SOFFICE = '/root/.claude/skills/synced/dac00b8e-f178-416f-8daa-4fbd8ef7c546_81e137d4-cd71-4da7-bad4-d36c9aac716a/docx/scripts/office/soffice.py'
MULTI = {'description', 'product_desc', 'target_market', 'market_area', 'media', 'experience'}


def render(values, flags, name):
    docx = os.path.join(OUT, name + '.docx')
    fill(os.path.join(HERE, 'templates', FORM + '.docx'), docx, values, flags)
    subprocess.run([sys.executable, SOFFICE, '--headless', '--convert-to', 'pdf', '--outdir', OUT, docx], capture_output=True)
    return os.path.join(OUT, name + '.pdf')


def keys_and_flags(form):
    xml = zipfile.ZipFile(os.path.join(HERE, 'templates', form + '.docx')).read('word/document.xml').decode()
    keys = sorted(set(re.findall(r'\{\{(\w+)(?:\|[^}]*)?\}\}', xml)))
    global DEFAULTED
    DEFAULTED = set(re.findall(r'\{\{(\w+)\|', xml))
    flags = sorted(set(re.findall(r'\{\{#(\w+)\}\}', xml)))
    return keys, flags


def page_chars(page):
    cs = [c for c in page.chars if c['text'].strip() or c['text'] == ' ']
    return cs


def find_tokens(pdf_path, tokens):
    """token -> list of (page, x0, top, x1, bottom, size)."""
    found = {}
    with pdfplumber.open(pdf_path) as pdf:
        for pi, page in enumerate(pdf.pages):
            for w in page.extract_words():
                if 'QZ' not in w['text']:
                    continue
                cs = sorted([c for c in page.chars if c['x0'] >= w['x0'] - 0.5 and c['x1'] <= w['x1'] + 0.5
                             and abs(c['top'] - w['top']) < 3], key=lambda c: c['x0'])
                text = ''.join(c['text'] for c in cs)
                for m in re.finditer(r'QZ', text):
                    tok = 'QZ'
                    sub = cs[m.start():m.end()]
                    found.setdefault(tok, []).append((pi, min(c['x0'] for c in sub), min(c['top'] for c in sub),
                                                      max(c['x1'] for c in sub), max(c['bottom'] for c in sub), sub[0]['size']))
    return found


def drawings(pdf_path):
    out = []
    with pdfplumber.open(pdf_path) as pdf:
        for pi, page in enumerate(pdf.pages):
            for o in page.curves + page.lines:
                out.append((pi, round(o['x0'], 1), round(o['top'], 1), round(o['x1'], 1), round(o['bottom'], 1)))
    return out


def measure(form):
    global FORM
    FORM = form
    keys, flags = keys_and_flags(form)
    filler = {k: ('' if k in DEFAULTED else '\u00a0') for k in keys}
    blank_pdf = render(filler, set(), form + '-blank')
    found = {}
    for k in keys:
        vals = dict(filler); vals[k] = 'QZ'
        f = find_tokens(render(vals, set(), form + '-tok'), ['QZ'])
        if f.get('QZ'):
            found[k] = f['QZ']
    tokens = {k: k for k in keys}
    layout = {'pages': [], 'fields': {}, 'checks': {}}
    with pdfplumber.open(blank_pdf) as pdf:
        pages = pdf.pages
        for pi, page in enumerate(pages):
            layout['pages'].append({'w': round(page.width, 2), 'h': round(page.height, 2)})
        words = [[w for w in p.extract_words()] for p in pages]
        vedges = [[e for e in p.edges if e['orientation'] == 'v' and e['height'] > 6] for p in pages]
        for k in keys:
            for (pi, x0, top, x1, bottom, size) in found.get(k, []):
                page = pages[pi]
                right = page.width - 40
                for w in words[pi]:
                    if abs(w['top'] - top) < 4 and w['x0'] > x0 + 2 and not set(w['text']) <= set('_'):
                        right = min(right, w['x0'] - 3)
                for e in vedges[pi]:
                    if e['x0'] > x0 + 2 and e['top'] <= top + 2 and e['bottom'] >= bottom - 2:
                        right = min(right, e['x0'] - 2)
                box = {'p': pi, 'x': round(x0, 1), 'y': round(top, 1), 'w': round(max(right - x0, 30), 1),
                       'h': round(bottom - top, 1), 'size': round(size, 1)}
                if k in MULTI:
                    below = [w['top'] for w in words[pi] if w['top'] > bottom + 2]
                    box['h'] = round((min(below) if below else page.height - 60) - top - 4, 1)
                    box['multi'] = True
                layout['fields'].setdefault(k, []).append(box)
        missing = [k for k in keys if k not in layout['fields']]
        if missing:
            print(form, 'NOT FOUND', missing)

    # check boxes: render each flag alone and see which new drawing appears
    base = set(drawings(blank_pdf))
    for fl in flags:
        new = [d for d in drawings(render(filler, {fl}, form + '-flag')) if d not in base]
        if not new:
            print(form, 'no tick for', fl)
            continue
        pi = new[0][0]
        x0 = min(d[1] for d in new); top = min(d[2] for d in new); x1 = max(d[3] for d in new); bot = max(d[4] for d in new)
        layout['checks'][fl] = {'p': pi, 'x': x0, 'y': top, 'w': round(x1 - x0, 1), 'h': round(bot - top, 1)}

    # blank page pictures
    subprocess.run(['pdftoppm', '-png', '-r', '144', blank_pdf, os.path.join(OUT, form)], check=True)
    return layout


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    result = {f: measure(f) for f in ('annexA', 'annexC', 'annexD')}
    json.dump(result, open(os.path.join(OUT, 'forms_layout.json'), 'w'), indent=1)
    for f, l in result.items():
        print(f, len(l['pages']), 'pages', len(l['fields']), 'fields', len(l['checks']), 'checks')
