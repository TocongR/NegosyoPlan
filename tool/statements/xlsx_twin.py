"""Python twin of lib/services/statements_xlsx.dart, to check the Excel output."""
import zipfile, sys
from sim import sample

ROWS = {
 'income': [('SALES','sales',0,1,1,'s',''),None,('Less: Cost of Sales',None,0,1,0,'',''),('Beginning Inventory','bi',2,0,0,'',''),('Purchases','pu',2,0,0,'s',''),
   ('Total Goods available for sale','tga',2,1,0,'',''),('Ending Inventory','ei',2,0,0,'s',''),('Total Cost of Sales','tcs',2,1,0,'s',''),None,
   ('GROSS INCOME','gi',0,1,1,'s',''),None,('LESS: Operating Expenses',None,0,1,0,'',''),('Salaries and Wages','sw',2,0,1,'',''),('Permits and Licenses','pl',2,0,0,'',''),
   ('Power, Light, Water','plw',2,0,0,'',''),('Travel and Transportation','tt',2,0,0,'s',''),('Total Operating Expenses','toe',0,1,1,'s',''),None,('NET INCOME','ni',0,1,1,'d','')],
 'cashFlow': [('Cash Beginning January {first}','cb',0,0,0,'s',''),('Add:',None,0,1,0,'',''),('Income from operation','io',2,0,0,'s',''),('Total Cash','tc',0,1,1,'s',''),None,
   ('Less: Cash Disbursements','cd',0,0,0,'s',''),None,('Cash Ending:','ce',0,1,0,'d','')],
 'balance': [('ASSETS',None,0,1,0,'',''),('Current Assets',None,1,1,0,'',''),('Cash on Hand & in Bank','cash',2,0,1,'',''),('Merchandise Inventory','inv',2,0,0,'s',''),
   ('Total Current Assets','tca',1,1,1,'s',''),None,('Non - Current Assets',None,1,1,0,'',''),('Lot, Building','lb',2,0,1,'',''),('Accum. Depreciation','lbd',2,0,0,'',''),
   ('Cars, Motorcycle','cm',2,0,0,'',''),('Accum. Depreciation','cmd',2,0,0,'',''),('Equipment','eq',2,0,0,'',''),('Accum. Depreciation','eqd',2,0,0,'s',''),
   ('Total Non - Current Assets','tnca',1,1,0,'s',''),None,('TOTAL ASSETS','ta',0,1,1,'d',''),None,('LIABILITIES & CAPITAL',None,0,1,0,'',''),None,
   ('Capital, Beg.','capb',2,0,0,'','Capital'),('Accum. Net Income','ani',2,0,0,'',''),('Total','capt',2,0,0,'',''),('Less: Drawings','dr',2,0,0,'s',''),
   ('Total Capital','tcap',2,1,1,'s',''),None,('TOTAL LIABILITIES & CAPITAL','tlc',2,1,0,'d','')],
}
TITLES = {'income':'INCOME STATEMENT','cashFlow':'CASH FLOW STATEMENT','balance':'BALANCE SHEET'}
SEC = {'income':'inc','cashFlow':'cf','balance':'bs'}

def col(n):
    s=''
    n+=1
    while n: n,r=divmod(n-1,26); s=chr(65+r)+s
    return s

def esc(s): return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')

def build(years, figs, typed, business, address, owner_role, name):
    n=len(years); last=years[-1]; first=years[0]
    lastcol = 3 + 2*n - 1
    rows={}   # r -> list of cell xml
    merges=[]; breaks=[]
    ref={}    # (sec,key,i) -> cell
    r=1
    def cell(rr,c,xml): rows.setdefault(rr,[]).append((c,xml))
    def s_(rr,c,text,style): cell(rr,c,f'<c r="{col(c)}{rr}" s="{style}" t="inlineStr"><is><t xml:space="preserve">{esc(text)}</t></is></c>')
    layout=[]
    for t in ('income','cashFlow','balance'):
        if r>1: breaks.append(r-1)
        s_(r,0,business,2); merges.append(f'A{r}:{col(lastcol)}{r}'); r+=1
        s_(r,0,address,3); merges.append(f'A{r}:{col(lastcol)}{r}'); r+=2
        s_(r,0,TITLES[t],4); merges.append(f'A{r}:{col(lastcol)}{r}'); r+=1
        s_(r,0,f'For the Period Ended December 31, {last}',5); merges.append(f'A{r}:{col(lastcol)}{r}'); r+=2
        for i,y in enumerate(years): cell(r,4+2*i,f'<c r="{col(4+2*i)}{r}" s="9"><v>{y}</v></c>')
        r+=2
        for row in ROWS[t]:
            if row is None: r+=1; continue
            label,key,level,bold,peso,rule,side=row
            label=label.replace('{first}',str(first))
            if side: s_(r,0,side,1)
            s_(r,level,label,1 if bold else 0)
            if key:
                for i in range(n): ref[(t,key,i)]=f'{col(4+2*i)}{r}'
            layout.append((t,r,key,bold,peso,rule))
            r+=1
        r+=1
        s_(r,lastcol-3,'Certified by:',0); r+=2
        s_(r,lastcol-3,name,15); s_(r,lastcol-2,'',16); s_(r,lastcol-1,'',16)
        r+=1
        s_(r,lastcol-3,owner_role,0); r+=2
    def F(t,key,i): return ref[(t,key,i)]
    for (t,rr,key,bold,peso,rule) in layout:
        if not key: continue
        for i,y in enumerate(years):
            c=4+2*i; a=F(t,key,i)
            f=None
            if t=='income':
                f={'tga':f'SUM({F(t,"bi",i)},{F(t,"pu",i)})','tcs':f'{F(t,"tga",i)}-{F(t,"ei",i)}','gi':f'{F(t,"sales",i)}-{F(t,"tcs",i)}',
                   'toe':f'SUM({F(t,"sw",i)},{F(t,"pl",i)},{F(t,"plw",i)},{F(t,"tt",i)})','ni':f'{F(t,"gi",i)}-{F(t,"toe",i)}'}.get(key)
            elif t=='cashFlow':
                f={'io':F('income','ni',i),'tc':f'SUM({F(t,"cb",i)},{F(t,"io",i)})','ce':f'{F(t,"tc",i)}-{F(t,"cd",i)}'}.get(key)
                if key=='cb' and i>0: f=F(t,'ce',i-1)
            else:
                f={'inv':F('income','ei',i),'tca':f'SUM({F(t,"cash",i)},{F(t,"inv",i)})',
                   'tnca':f'{F(t,"lb",i)}-{F(t,"lbd",i)}+{F(t,"cm",i)}-{F(t,"cmd",i)}+{F(t,"eq",i)}-{F(t,"eqd",i)}',
                   'ta':f'{F(t,"tca",i)}+{F(t,"tnca",i)}','ani':F('income','ni',i),'capt':f'SUM({F(t,"capb",i)},{F(t,"ani",i)})',
                   'dr':f'{F(t,"capt",i)}-{F(t,"ta",i)}','tcap':f'{F(t,"capt",i)}-{F(t,"dr",i)}','tlc':F(t,'tcap',i)}.get(key)
                if key=='capb' and i>0: f=F(t,'tcap',i-1)
            style = {('',0):10,('',1):11,('s',0):12,('s',1):13,('d',0):14,('d',1):14}[(rule,bold)]
            v=figs[y][SEC[t]].get(key)
            vx='' if v is None else f'<v>{float(v)}</v>'
            if f: cell(rr,c,f'<c r="{a}" s="{style}"><f>{esc(f)}</f>{vx}</c>')
            elif v is not None: cell(rr,c,f'<c r="{a}" s="{style}"><v>{float(v)}</v></c>')
            else: cell(rr,c,f'<c r="{a}" s="{style}"/>')
            if peso: s_(rr,c-1,'P',1)
    sheet=['<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
      '<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr><sheetViews><sheetView workbookViewId="0" showGridLines="0"/></sheetViews><sheetFormatPr defaultRowHeight="12" customHeight="1"/>',
      '<cols><col min="1" max="1" width="3" customWidth="1"/><col min="2" max="2" width="3" customWidth="1"/><col min="3" max="3" width="32" customWidth="1"/>']
    for i in range(n):
        sheet.append(f'<col min="{4+2*i}" max="{4+2*i}" width="2.5" customWidth="1"/><col min="{5+2*i}" max="{5+2*i}" width="14" customWidth="1"/>')
    sheet.append('</cols><sheetData>')
    for rr in sorted(rows):
        cs=sorted([x for x in rows[rr] if x[1]], key=lambda x:x[0])
        sheet.append(f'<row r="{rr}">'+''.join(x for _,x in cs)+'</row>')
    sheet.append('</sheetData>')
    sheet.append(f'<mergeCells count="{len(merges)}">'+''.join(f'<mergeCell ref="{m}"/>' for m in merges)+'</mergeCells>')
    sheet.append('<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>')
    sheet.append(f'<pageSetup paperSize="9" orientation="{"landscape" if n>6 else "portrait"}" fitToWidth="1" fitToHeight="0"/>')
    sheet.append(f'<rowBreaks count="{len(breaks)}" manualBreakCount="{len(breaks)}">'+''.join(f'<brk id="{b}" max="16383" man="1"/>' for b in breaks)+'</rowBreaks>')
    sheet.append('</worksheet>')
    return ''.join(sheet)

STYLES='''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.00_);(#,##0.00);&quot;-&quot;_)"/></numFmts>
<fonts count="6"><font><sz val="9"/><name val="Calibri"/></font><font><b/><sz val="9"/><name val="Calibri"/></font><font><b/><sz val="8"/><name val="Calibri"/></font><font><i/><sz val="8"/><name val="Calibri"/></font><font><b/><sz val="12"/><name val="Calibri"/></font><font><sz val="11"/><name val="Calibri"/></font></fonts>
<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
<borders count="4"><border><left/><right/><top/><bottom/><diagonal/></border><border><left/><right/><top/><bottom style="thin"/><diagonal/></border><border><left/><right/><top/><bottom style="double"/><diagonal/></border><border><left/><right/><top style="thin"/><bottom/><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="17">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>
<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>
<xf numFmtId="0" fontId="4" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>
<xf numFmtId="0" fontId="5" fillId="0" borderId="0" xfId="0" applyFont="1" applyAlignment="1"><alignment horizontal="center"/></xf>
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center"/></xf>
<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="164" fontId="1" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyFont="1"/>
<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>
<xf numFmtId="164" fontId="1" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>
<xf numFmtId="164" fontId="1" fillId="0" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>
<xf numFmtId="0" fontId="1" fillId="0" borderId="3" xfId="0" applyFont="1" applyBorder="1"/>
<xf numFmtId="0" fontId="0" fillId="0" borderId="3" xfId="0" applyBorder="1"/>
</cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>'''

def package(sheet, path):
    files={
     '[Content_Types].xml':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>',
     '_rels/.rels':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
     'xl/workbook.xml':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Financial Statements" sheetId="1" r:id="rId1"/></sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>',
     'xl/_rels/workbook.xml.rels':'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>',
     'xl/styles.xml':STYLES,
     'xl/worksheets/sheet1.xml':sheet,
    }
    with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED) as z:
        for k,v in files.items(): z.writestr(k,v)

if __name__=='__main__':
    Y=sample(False)
    years=sorted(Y)
    figs={y:{'inc':Y[y]['fig'][0],'cf':Y[y]['fig'][1],'bs':Y[y]['fig'][2]} for y in years}
    package(build(years,figs,None,"LOLA NENA'S PIAYA",'Tabuc Suba, Iloilo City, Iloilo','Proprietress','Maria Lopez Santos'),'fs_out.xlsx')
    print('ok')
