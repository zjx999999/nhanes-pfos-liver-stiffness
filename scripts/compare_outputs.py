"""Compare all 17 frozen CSVs and the independent primary/contrast exports; never alter inputs."""
from pathlib import Path
import csv,math,json,hashlib
R=Path(__file__).resolve().parents[1];A=R/'analysis/outputs'
def read(p):
 with p.open(encoding='utf-8-sig',newline='') as f:r=csv.DictReader(f);return r.fieldnames,list(r)
def same(x,y):
 if x==y:return True
 try:return math.isclose(float(x),float(y),rel_tol=1e-9,abs_tol=1e-11)
 except (ValueError,TypeError):return False
results=[];errors=[]
for ref in sorted((R/'data').glob('*.csv')):
 actual=A/ref.name
 if not actual.exists():errors.append('Missing regenerated output: '+ref.name);continue
 h,a=read(ref);j,b=read(actual)
 if h!=j or len(a)!=len(b):errors.append('Schema/row count differs: '+ref.name);continue
 mismatch=[(i,k,x[k],y[k]) for i,(x,y) in enumerate(zip(a,b),1) for k in h if not same(x[k],y[k])]
 for i,k,x,y in mismatch:errors.append(f'{ref.name}, row {i}, {k}: {x} vs {y}')
 results.append({'file':ref.name,'rows':len(a),'status':'matched' if not mismatch else 'mismatch','byte_identical':ref.read_bytes()==actual.read_bytes()})
# Independent implementation covers available-case base and complete-case extended models only.
_,ind=read(A/'independent_primary_recalc.csv');_,primary=read(R/'data/primary_model_comparison.csv');fields=['n','beta','se','design_df','residual_df','ci_low','ci_high','p','ci_low_residual','ci_high_residual','p_residual']
ind_checks=[]
for row in ind:
 expected=next(r for r in primary if (r['period'],r['model'])==(row['period'],row['model']))
 for k in fields:
  ok=same(expected[k],row[k]);ind_checks.append({'period':row['period'],'model':row['model'],'field':k,'expected':expected[k],'actual':row[k],'match':ok})
  if not ok:errors.append('Independent primary mismatch: '+row['period']+' '+row['model']+' '+k)
_,indcontrast=read(A/'independent_period_contrast.csv');_,frozencontrast=read(R/'data/cycle_effect_difference.csv');wide=indcontrast[0]
contrast_checks=[]
for row in frozencontrast:
 suffix='design_df' if row['inference']=='design_df_primary' else 'residual_df'
 mapping={'beta_difference_2021_minus_2017':'delta_2021_minus_2017','se':'se','df':'df_using_'+('design_df' if suffix=='design_df' else 'model_residual'),'ci_low':'ci_low_'+suffix,'ci_high':'ci_high_'+suffix,'p_difference':'p_'+suffix}
 for key,col in mapping.items():
  ok=same(row[key],wide[col]);contrast_checks.append({'inference':row['inference'],'field':key,'expected':row[key],'actual':wide[col],'match':ok})
  if not ok:errors.append('Independent period contrast mismatch: '+row['inference']+' '+key)
result={'files':results,'required_frozen_files':17,'compared_frozen_files':len(results),'independent_primary_checks':ind_checks,'independent_contrast_checks':contrast_checks,'errors':errors,'relative_tolerance':1e-9,'absolute_tolerance':1e-11,'meaning':'Numerical reproduction only, not independent human scientific review'}
(A/'reproduction_comparison.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
if errors or len(results)!=17:raise SystemExit('Reproduction comparison failed; frozen files retained unchanged')
