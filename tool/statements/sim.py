CALC={'tga','tcs','gi','toe','ni','io','tc','ce','inv','tca','tnca','ta','ani','capt','dr','tcap','tlc'}
CARRY={'cb':'ce','capb':'tcap'}
def num(x):
    try: return float(str(x).replace(',',''))
    except: return None
def compute(inc,cf,bs,prev):
    t=lambda m:{k:v for k,v in m.items() if k not in CALC and not (prev and k in CARRY)}
    i,c,b=t(inc),t(cf),t(bs)
    v=lambda m,k: num(m[k]) if k in m else None
    def add(xs): return None if all(x is None for x in xs) else sum(x or 0 for x in xs)
    def sub(a,bb): return None if a is None and bb is None else (a or 0)-(bb or 0)
    def put(m,k,x):
        if x is not None: m[k]=x
    put(i,'tga',add([v(i,'bi'),v(i,'pu')])); put(i,'tcs',sub(v(i,'tga'),v(i,'ei'))); put(i,'gi',sub(v(i,'sales'),v(i,'tcs')))
    put(i,'toe',add([v(i,k) for k in ('sw','pl','plw','tt')])); put(i,'ni',sub(v(i,'gi'),v(i,'toe')))
    if prev: put(c,'cb',v(prev[1],'ce'))
    put(c,'io',v(i,'ni')); put(c,'tc',add([v(c,'cb'),v(c,'io')])); put(c,'ce',sub(v(c,'tc'),v(c,'cd')))
    put(b,'inv',v(i,'ei')); put(b,'tca',add([v(b,'cash'),v(b,'inv')]))
    neg=lambda x: None if x is None else -x
    put(b,'tnca',add([v(b,'lb'),neg(v(b,'lbd')),v(b,'cm'),neg(v(b,'cmd')),v(b,'eq'),neg(v(b,'eqd'))]))
    put(b,'ta',add([v(b,'tca'),v(b,'tnca')]))
    if prev: put(b,'capb',v(prev[2],'tcap'))
    put(b,'ani',v(i,'ni')); put(b,'capt',add([v(b,'capb'),v(b,'ani')]))
    if v(b,'capt') is not None and v(b,'ta') is not None: put(b,'dr',v(b,'capt')-v(b,'ta'))
    put(b,'tcap',sub(v(b,'capt'),v(b,'dr'))); put(b,'tlc',v(b,'tcap'))
    return i,c,b
def sample(clear=True):
    base=dict(inc={'sales':820000,'bi':20000,'pu':400000,'ei':15000,'sw':156000,'pl':6000,'plw':36000,'tt':24000},
              cf={'cb':30000,'cd':180000},bs={'cash':43000,'lb':60000,'lbd':12000,'cm':70000,'cmd':28000,'eq':25000,'eqd':10000,'capb':50000})
    sc={2019:.2,2020:.32,2021:.46,2022:.62,2023:.78,2024:.89,2025:1}
    Y={}
    for y,f in sc.items():
        d={k:{kk:round(vv*f/1000)*1000 for kk,vv in m.items()} for k,m in base.items()}
        if clear and y==2019: d['cf']={}; d['bs']={}
        if clear and y==2022: d['cf']={}
        Y[y]=d
    prev=None
    for y in sorted(Y):
        d=Y[y]; f=compute(d['inc'],d['cf'],d['bs'],prev)
        if d['bs'] and f[1].get('ce') is not None:
            d['bs']['cash']=f[1]['ce']; f=compute(d['inc'],d['cf'],d['bs'],prev)
        prev=f; Y[y]['fig']=f
    return Y
if __name__=='__main__':
    for clear in (True,False):
        Y=sample(clear)
        for y in sorted(Y):
            i,c,b=Y[y]['fig']; print(clear,y,'ni',i.get('ni'),'cb',c.get('cb'),'ce',c.get('ce'),'ta',b.get('ta'),'capb',b.get('capb'),'dr',b.get('dr'),'tcap',b.get('tcap'))
