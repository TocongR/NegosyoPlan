"""Put fill-in placeholders into the three official templates.

Placeholders (read by DocxFiller in the app):
  {{key}} or {{key|default}}  inside a <w:t>   -> the value (default when blank)
  <w:r><w:t>{{#flag}}</w:t></w:r> ... <w:r><w:t>{{/flag}}</w:t></w:r>
                                               -> kept only when the flag is on
The layout, wording and boxes of the originals are not changed.
"""
import copy, os, shutil, subprocess, sys
from lxml import etree

HERE = os.path.dirname(os.path.abspath(__file__))
NS = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'wps': 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
    'mc': 'http://schemas.openxmlformats.org/markup-compatibility/2006',
}
W = '{%s}' % NS['w']
WP = '{%s}' % NS['wp']
XS = '{http://www.w3.org/XML/1998/namespace}space'


class Doc:
    def __init__(self, name):
        self.dir = os.path.join(HERE, 'u_' + name)
        self.path = os.path.join(self.dir, 'word', 'document.xml')
        self.tree = etree.parse(self.path)
        self.body = self.tree.getroot().find(W + 'body')
        self.ps = list(self.body.iter(W + 'p'))  # indexes match dump.py
        self.next_id = 5000

    # ---- runs ----
    def _rpr_of(self, p):
        for r in p.findall(W + 'r'):
            if r.find(W + 't') is not None and r.find(W + 'rPr') is not None:
                return copy.deepcopy(r.find(W + 'rPr'))
        ppr = p.find(W + 'pPr')
        if ppr is not None and ppr.find(W + 'rPr') is not None:
            return copy.deepcopy(ppr.find(W + 'rPr'))
        return etree.Element(W + 'rPr')

    def run(self, text, rpr=None, size=None, underline=None, bold=False, font=None):
        r = etree.Element(W + 'r')
        rpr = copy.deepcopy(rpr) if rpr is not None else etree.Element(W + 'rPr')
        for tag in ('position', 'spacing'):
            for e in rpr.findall(W + tag):
                rpr.remove(e)
        if underline is False:
            for e in rpr.findall(W + 'u'):
                rpr.remove(e)
        if size:
            for tag in ('sz', 'szCs'):
                for e in rpr.findall(W + tag):
                    rpr.remove(e)
            etree.SubElement(rpr, W + 'sz').set(W + 'val', str(size))
        if bold:
            rpr.insert(0, etree.Element(W + 'b'))
        if font:
            for e in rpr.findall(W + 'rFonts'):
                rpr.remove(e)
            f = etree.Element(W + 'rFonts')
            for k in ('ascii', 'hAnsi', 'cs'):
                f.set(W + k, font)
            rpr.insert(0, f)
        if len(rpr):
            # schema order: rFonts, b, ..., u ... sz; good enough to sort the few we touch
            order = ['rStyle', 'rFonts', 'b', 'bCs', 'i', 'iCs', 'caps', 'color', 'spacing', 'w', 'kern', 'position', 'sz', 'szCs', 'highlight', 'u', 'vertAlign', 'lang']
            kids = sorted(list(rpr), key=lambda e: order.index(etree.QName(e).localname) if etree.QName(e).localname in order else 99)
            for k in kids:
                rpr.remove(k)
            for k in kids:
                rpr.append(k)
            r.append(rpr)
        t = etree.SubElement(r, W + 't')
        t.text = text
        if text.strip() != text or True:
            t.set(XS, 'preserve')
        return r

    @staticmethod
    def marker(text):
        r = etree.Element(W + 'r')
        etree.SubElement(r, W + 't').text = text
        return r

    # ---- placing values ----
    def append(self, i, key, sep='', **kw):
        """Add {{key}} at the end of paragraph i."""
        p = self.ps[i]
        rpr = kw.pop('rpr', None)
        p.append(self.run(sep + '{{%s}}' % key, rpr if rpr is not None else self._rpr_of(p), **kw))

    def new_par(self, i, key, size=18, before=0, keep_ind=True):
        """Add a new paragraph right after paragraph i holding {{key}}."""
        p = self.ps[i]
        np_ = etree.Element(W + 'p')
        ppr = copy.deepcopy(p.find(W + 'pPr')) if p.find(W + 'pPr') is not None else etree.Element(W + 'pPr')
        for tag in ('numPr', 'tabs'):
            for e in ppr.findall(W + tag):
                ppr.remove(e)
        for e in ppr.findall(W + 'spacing'):
            ppr.remove(e)
        sp = etree.Element(W + 'spacing')
        sp.set(W + 'before', str(before))
        # spacing goes after pStyle/keepNext.. and before ind
        idx = 1 if ppr.find(W + 'pStyle') is not None else 0
        ppr.insert(idx, sp)
        np_.append(ppr)
        np_.append(self.run('{{%s}}' % key, self._rpr_of(p), size=size, underline=False))
        p.addnext(np_)
        return np_

    def tabbed_par(self, i, keys_tabs, size=18, ind=52):
        """New paragraph after i with values placed at tab stops: [(key, pos|None), ...]."""
        p = self.ps[i]
        np_ = etree.SubElement(p.getparent(), W + 'p')
        p.addnext(np_)
        ppr = etree.SubElement(np_, W + 'pPr')
        etree.SubElement(ppr, W + 'pStyle').set(W + 'val', 'TableParagraph')
        tabs = etree.SubElement(ppr, W + 'tabs')
        for _, pos in keys_tabs:
            if pos:
                tb = etree.SubElement(tabs, W + 'tab')
                tb.set(W + 'val', 'left'); tb.set(W + 'pos', str(pos))
        etree.SubElement(ppr, W + 'ind').set(W + 'left', str(ind))
        rpr = etree.Element(W + 'rPr')
        for k, pos in keys_tabs:
            if pos:
                r = etree.SubElement(np_, W + 'r')
                etree.SubElement(r, W + 'tab')
            np_.append(self.run('{{%s}}' % k, rpr, size=size, underline=False))

    def before_blank(self, i, n, key, size=None, drop_tab=False, lead=''):
        """Put {{key}} on the n-th underlined blank (a run of underlined tabs) of paragraph i."""
        p = self.ps[i]
        blanks = [r for r in p.findall(W + 'r') if r.find(W + 'rPr') is not None and r.find(W + 'rPr').find(W + 'u') is not None
                  and r.find(W + 'tab') is not None and r.find(W + 't') is None]
        r = blanks[n]
        r.addprevious(self.run(lead + '{{%s}}' % key, r.find(W + 'rPr'), size=size))
        if drop_tab and len(r.findall(W + 'tab')) > 1:
            r.remove(r.findall(W + 'tab')[0])

    def after_text(self, i, text, key, sep=' ', **kw):
        p = self.ps[i]
        for r in p.findall(W + 'r'):
            t = r.find(W + 't')
            if t is not None and text in (t.text or ''):
                r.addnext(self.run(sep + '{{%s}}' % key, r.find(W + 'rPr'), **kw))
                return
        raise ValueError('text %r not in p%d' % (text, i))

    def replace_text(self, i, old, new):
        for t in self.ps[i].iter(W + 't'):
            if old in (t.text or ''):
                t.text = t.text.replace(old, new)
                t.set(XS, 'preserve')
                return
        raise ValueError('text %r not in p%d' % (old, i))

    # ---- check boxes ----
    def check(self, box_id, flag):
        """Add a check mark over the box drawing with docPr id=box_id, shown only when flag is on."""
        dp = [d for d in self.body.iter(WP + 'docPr') if d.get('id') == str(box_id)][0]
        anchor = dp.getparent()
        run = anchor
        while run.tag != W + 'r':
            run = run.getparent()
        h = anchor.find(WP + 'positionH'); v = anchor.find(WP + 'positionV'); ext = anchor.find(WP + 'extent')
        cx, cy = int(ext.get('cx')), int(ext.get('cy'))
        self.next_id += 1
        nid = self.next_id
        tick = f'''<w:r xmlns:w="{NS['w']}" xmlns:wp="{NS['wp']}" xmlns:a="{NS['a']}" xmlns:wps="{NS['wps']}" xmlns:mc="{NS['mc']}"><mc:AlternateContent><mc:Choice Requires="wps"><w:drawing><wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="{487400000 + nid}" behindDoc="0" locked="0" layoutInCell="1" allowOverlap="1"><wp:simplePos x="0" y="0"/><wp:positionH relativeFrom="{h.get('relativeFrom')}"><wp:posOffset>{h.find(WP + 'posOffset').text}</wp:posOffset></wp:positionH><wp:positionV relativeFrom="{v.get('relativeFrom')}"><wp:posOffset>{v.find(WP + 'posOffset').text}</wp:posOffset></wp:positionV><wp:extent cx="{cx}" cy="{cy}"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:wrapNone/><wp:docPr id="{nid}" name="Check {nid}"/><wp:cNvGraphicFramePr/><a:graphic><a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"><wps:wsp><wps:cNvSpPr/><wps:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:custGeom><a:avLst/><a:gdLst/><a:ahLst/><a:cxnLst/><a:rect l="l" t="t" r="r" b="b"/><a:pathLst><a:path w="100" h="100" fill="none"><a:moveTo><a:pt x="14" y="52"/></a:moveTo><a:lnTo><a:pt x="40" y="80"/></a:lnTo><a:lnTo><a:pt x="88" y="14"/></a:lnTo></a:path></a:pathLst></a:custGeom><a:noFill/><a:ln w="19050" cap="rnd"><a:solidFill><a:srgbClr val="000000"/></a:solidFill><a:round/></a:ln></wps:spPr><wps:bodyPr/></wps:wsp></a:graphicData></a:graphic></wp:anchor></w:drawing></mc:Choice></mc:AlternateContent></w:r>'''
        t = etree.fromstring(tick)
        run.addnext(self.marker('{{#%s}}' % flag))
        run.getnext().addnext(t)
        t.addnext(self.marker('{{/%s}}' % flag))

    def text_check(self, i, flag, mark='✓ '):
        """Put a check mark at the start of paragraph i, shown only when flag is on."""
        p = self.ps[i]
        first = [r for r in p.findall(W + 'r')][0]
        rpr = self._rpr_of(p)
        first.addprevious(self.marker('{{#%s}}' % flag))
        first.addprevious(self.run(mark, rpr, bold=True, font='Segoe UI Symbol'))
        first.addprevious(self.marker('{{/%s}}' % flag))

    def save(self, out):
        self.tree.write(self.path, xml_declaration=True, encoding='UTF-8', standalone=True)
        if os.path.exists(out):
            os.remove(out)
        subprocess.check_call(['zip', '-qXr', out, '.'], cwd=self.dir)


def annex_a():
    d = Doc('annexA')
    # A. Personal profile
    d.new_par(11, 'last'); d.new_par(13, 'first'); d.new_par(14, 'middle')
    # Address under (Lot No.)(Street) | (Brgy.) | (Municipality) | (Province)
    d.tabbed_par(19, [('h_street', None), ('h_brgy', 2723), ('h_town', 4103), ('h_prov', 6017)])
    for n, key in enumerate(['d1', 'd2', 'd3', 'd4', 'd5']):
        d.check([6, 8, 10, 12, 14][n], key)
    d.new_par(27, 'dob'); d.new_par(28, 'age')
    d.check(18, 'male'); d.check(16, 'female')
    d.new_par(30, 'contact'); d.new_par(31, 'fb'); d.new_par(32, 'email')
    d.new_par(33, 'tin'); d.new_par(34, 'bank')
    d.check(20, 'single'); d.check(24, 'married'); d.check(22, 'widow'); d.check(26, 'separated')
    # B. Business profile
    d.append(42, 'business', sep='   ', size=18, underline=False)
    d.tabbed_par(43, [('b_street', None), ('b_brgy', 2723), ('b_town', 4103), ('b_prov', 6017)])
    d.new_par(44, 'years_op')
    d.before_blank(50, 0, 'emp_m'); d.append(50, 'emp_f', sep=' ', underline=None)
    d.before_blank(51, 0, 'emp_total')
    d.before_blank(52, 0, 'st_perm'); d.before_blank(52, 1, 'st_contract')
    d.before_blank(53, 0, 'st_casual'); d.before_blank(53, 1, 'st_seasonal'); d.before_blank(53, 2, 'st_other')
    d.check(30, 'reg_dti'); d.check(32, 'reg_sec'); d.check(34, 'reg_mayor'); d.check(36, 'reg_brgy')
    d.check(38, 'type_mfg'); d.check(40, 'type_trading'); d.check(42, 'type_service')
    d.check(44, 'own_single'); d.check(46, 'own_partner'); d.check(48, 'own_other')
    d.before_blank(70, 0, 'prod1')
    for i, k in ((72, 'prod2'), (74, 'prod3'), (76, 'prod4'), (82, 'prod5')):
        d.after_text(i, ')', k)
    d.before_blank(71, 0, 'capital'); d.before_blank(75, 0, 'gross_sales'); d.before_blank(83, 0, 'net_assets')
    # C. Application details: amount only (period and purpose are not asked)
    d.new_par(86, 'loan', size=20)
    # Disclosure statement
    d.before_blank(112, 0, 'full_name'); d.before_blank(112, 1, 'home_address')
    d.append(116, 'full_name_sign', size=18, underline=False, rpr=etree.Element(W + 'rPr'))
    return d


def annex_c():
    d = Doc('annexC')
    d.before_blank(1, 1, 'brgy'); d.before_blank(1, 2, 'brgy', drop_tab=False)
    d.before_blank(2, 0, 'owner', drop_tab=True); d.before_blank(2, 1, 'resident_since', lead=' ')
    d.before_blank(18, 0, 'brgy', drop_tab=True); d.before_blank(18, 1, 'brgy')
    d.before_blank(19, 0, 'owner', lead=' ')
    d.before_blank(20, 0, 'business', drop_tab=True); d.before_blank(20, 1, 'operating_since', lead=' ')
    d.text_check(23, 'closed'); d.text_check(24, 'lost_sales')
    return d


def annex_d():
    d = Doc('annexD')
    for i, k in ((8, 'project'), (10, 'company'), (12, 'address'), (14, 'nature'), (16, 'form'), (18, 'owner'), (20, 'contact')):
        d.append(i, k, sep=' ')
    d.append(23, 'description')
    d.append(30, 'product_desc'); d.append(35, 'target_market'); d.append(40, 'market_area'); d.append(44, 'media')
    # 2.5 selling price: rows 1-5
    for n, (c0, c1) in enumerate([(51, 52), (53, 54), (55, 56), (57, 58), (59, 60)], 1):
        d.append(c0, 'price%d_name' % n, sep=' ' if n > 3 else '')
        d.append(c1, 'price%d' % n)
    # 3. raw materials and source: 7 rows
    for n in range(7):
        d.append(69 + 2 * n, 'raw%d' % (n + 1)); d.append(70 + 2 * n, 'raw%d_src' % (n + 1))
    for n, i in enumerate(range(85, 90), 1):
        d.replace_text(i, '_______________________________', '{{tool%d|_______________________________}}' % n)
    for i, k in ((98, 'pc_materials'), (100, 'pc_labor'), (102, 'pc_overhead'), (104, 'pc_total'), (106, 'pc_units'), (108, 'pc_per_unit')):
        d.append(i, k)
    d.append(114, 'experience')
    for n in range(5):
        base = 126 + 3 * n
        d.append(base, 'emp%d' % (n + 1)); d.append(base + 1, 'emp%d_work' % (n + 1)); d.append(base + 2, 'emp%d_status' % (n + 1))
    d.append(142, 'emp_total')
    d.replace_text(167, '_________________________________', '{{loan|_________________________________}}')
    for i, k in ((195, 'sales'), (197, 'expenses'), (199, 'gross_income'), (201, 'net_income')):
        d.append(i, k)
    return d


if __name__ == '__main__':
    outdir = os.path.join(HERE, 'templates')
    os.makedirs(outdir, exist_ok=True)
    for name, fn in (('annexA', annex_a), ('annexC', annex_c), ('annexD', annex_d)):
        # start each build from a fresh unpack of the original
        src = os.path.join(HERE, 'src', name + '.docx')
        shutil.rmtree(os.path.join(HERE, 'u_' + name), ignore_errors=True)
        subprocess.check_call(['unzip', '-q', src, '-d', os.path.join(HERE, 'u_' + name)])
        subprocess.call(['find', os.path.join(HERE, 'u_' + name), '-type', 'l', '-delete'])
        fn().save(os.path.join(outdir, name + '.docx'))
        print('built', name)
