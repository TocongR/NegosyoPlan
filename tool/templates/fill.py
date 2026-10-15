"""Python twin of lib/services/docx_filler.dart, used to check the templates."""
import io, re, sys, zipfile, os

SECTION = re.compile(r'<w:r><w:t>\{\{#(\w+)\}\}</w:t></w:r>(.*?)<w:r><w:t>\{\{/\1\}\}</w:t></w:r>', re.S)
FIELD = re.compile(r'\{\{(\w+)(?:\|([^}]*))?\}\}')


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;')


def fill_xml(xml, values, flags):
    xml = SECTION.sub(lambda m: m.group(2) if m.group(1) in flags else '', xml)

    def field(m):
        v = values.get(m.group(1)) or ''
        if v != '\u00a0':
            v = v.strip()
        if not v:
            return esc(m.group(2) or '')
        return esc(v).replace('\n', '</w:t><w:br/><w:t xml:space="preserve">')
    return FIELD.sub(field, xml)


def fill(template, out, values, flags):
    zin = zipfile.ZipFile(template)
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                data = fill_xml(data.decode('utf8'), values, flags).encode('utf8')
            zout.writestr(item, data)
    open(out, 'wb').write(buf.getvalue())


# ---- sample: Lola Nena's Piaya (same as AppData.sample) ----
A = dict(
    last='Santos', first='Maria', middle='Lopez',
    h_street='', h_brgy='Tabuc Suba', h_town='Iloilo City', h_prov='Iloilo',
    dob='05/12/1981', age='45', contact='0917 123 4567', fb='', email='', tin='', bank='',
    business='Lola Nena’s Piaya',
    b_street='', b_brgy='Tabuc Suba', b_town='Iloilo City', b_prov='Iloilo', years_op='7',
    emp_m='1', emp_f='1', emp_total='2', st_perm='1', st_contract='0', st_casual='1', st_seasonal='0', st_other='0',
    prod1='Piaya', prod2='Ube piaya', capital='50,000.00', gross_sales='820,000.00', net_assets='163,000.00',
    loan='100,000.00', full_name='Maria Lopez Santos', home_address='Tabuc Suba, Iloilo City, Iloilo',
    full_name_sign='MARIA LOPEZ SANTOS',
)
A_FLAGS = {'d2', 'female', 'married', 'reg_mayor', 'type_mfg', 'own_single'}
C = dict(brgy='Tabuc Suba', owner='Maria Lopez Santos', resident_since='2012', business='Lola Nena’s Piaya', operating_since='June 2019')
C_FLAGS = {'lost_sales'}
D = dict(
    project='', company='Lola Nena’s Piaya', address='Tabuc Suba, Iloilo City, Iloilo', nature='Manufacturing / Processing',
    form='Single proprietorship', owner='Maria Lopez Santos', contact='0917 123 4567',
    description='Home-based bakery making piaya for stores in Jaro.',
    product_desc='Flat bread filled with muscovado, baked fresh daily and sold in packs of 10.',
    target_market='Sari-sari stores, Pasalubong shops', market_area='My town or city', media='Friends and neighbors, Facebook',
    price1_name='Piaya (pack of 10)', price1='120.00', price2_name='Ube piaya (pack of 10)', price2='140.00',
    raw1='Flour (25 kg)', raw1_src='Jaro Public Market', raw2='Muscovado sugar (10 kg)', raw2_src='Jaro Public Market',
    raw3='Margarine and oil (4 L)', raw3_src='Iloilo Supermart', raw4='Plastic packs (50 pcs)', raw4_src='Iloilo Terminal Market',
    tool1='Oven', tool2='Mixing bowls and trays',
    pc_materials='3,000.00', pc_labor='1,500.00', pc_overhead='700.00', pc_total='5,200.00', pc_units='50', pc_per_unit='104.00',
    experience='6 years baking and selling piaya',
    emp1='Ana Reyes', emp1_work='Baker', emp1_status='Permanent', emp2='Jun Panes', emp2_work='Packer and delivery', emp2_status='On-call',
    emp_total='2', loan='Php 100,000.00',
    sales='864,000.00', expenses='684,000.00', gross_income='432,000.00', net_income='180,000.00',
)

if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(os.path.join(here, 'out'), exist_ok=True)
    for name, v, f in (('annexA', A, A_FLAGS), ('annexC', C, C_FLAGS), ('annexD', D, set())):
        fill(os.path.join(here, 'templates', name + '.docx'), os.path.join(here, 'out', name + '-filled.docx'), v, f)
    print('ok')
