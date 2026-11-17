"""Assemble the saved probe sensitivity table from regenerated outputs; no fitting or reference values."""
from pathlib import Path
import argparse,csv,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--output-dir',type=Path,required=True);p.add_argument('--destination',type=Path);a=p.parse_args()
senspath=a.output_dir/'sensitivity_models.csv';primpath=a.output_dir/'primary_model_comparison.csv'
with senspath.open(encoding='utf-8-sig',newline='') as f:r=csv.DictReader(f);fields=r.fieldnames;rows=list(r)
with primpath.open(encoding='utf-8-sig',newline='') as f:primary=list(csv.DictReader(f))
probe=[r for r in primary if r['model']=='extended_plus_probe_same_complete_cases'];periods=list(dict.fromkeys(r['period'] for r in rows))
assert len(probe)==len(periods) and len(set(r['period'] for r in probe))==len(probe)
assembled=[]
for period in periods:
 assembled.extend(r for r in rows if r['period']==period)
 src=next(r for r in probe if r['period']==period)
 row={k:src[k] for k in fields if k not in ['sensitivity','model_residual_df']};row['sensitivity']='primary_plus_probe';row['model_residual_df']=src['residual_df'];assembled.append(row)
assert len({(r['period'],r['sensitivity']) for r in assembled})==len(assembled)
dest=a.destination or a.output_dir/'sensitivity_with_probe.csv';dest.parent.mkdir(parents=True,exist_ok=True)
with dest.open('w',newline='',encoding='utf-8') as f:w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(assembled)
print(json.dumps({'output':str(dest),'rows':len(assembled),'source_files':{q.name:hashlib.sha256(q.read_bytes()).hexdigest() for q in [senspath,primpath]},'reference_table_read':False,'model_fits':0},indent=2))
