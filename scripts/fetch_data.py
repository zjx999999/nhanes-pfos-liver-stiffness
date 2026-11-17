"""Retrieve or verify only the official manifest inputs; never overwrite a mismatched input."""
from pathlib import Path
import argparse,csv,hashlib,os,urllib.request
R=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--verify-only',action='store_true');args=p.parse_args()
root=Path(os.environ.get('NHANES_DATA_ROOT',R/'input_data')).expanduser()
manifest=R/'analysis/reproducibility/data_manifest.csv'
def digest(f):
 h=hashlib.sha256()
 with f.open('rb') as s:
  for chunk in iter(lambda:s.read(1024*1024),b''):h.update(chunk)
 return h.hexdigest()
rows=list(csv.DictReader(manifest.open()))
for row in rows:
 rel=Path(row['local_relative_path']);url=row['source_url'];assert not rel.is_absolute() and '..' not in rel.parts
 assert url.startswith('https://wwwn.cdc.gov/')
 target=root/rel
 if target.exists():
  if target.stat().st_size!=int(row['bytes']) or digest(target)!=row['sha256']:raise SystemExit('Existing input mismatch; retained without overwrite: '+str(target))
  print('Verified '+row['file']);continue
 if args.verify_only:raise SystemExit('Missing '+str(target))
 target.parent.mkdir(parents=True,exist_ok=True);tmp=target.with_suffix(target.suffix+'.download')
 try:
  with urllib.request.urlopen(url,timeout=120) as source,tmp.open('wb') as out:
   for chunk in iter(lambda:source.read(1024*1024),b''):out.write(chunk)
  if tmp.stat().st_size!=int(row['bytes']) or digest(tmp)!=row['sha256']:raise ValueError('Downloaded size/hash mismatch: '+row['file'])
  tmp.replace(target)
 finally:
  if tmp.exists():tmp.unlink()
 print('Downloaded and verified '+row['file'])
print('Verified '+str(len(rows))+' official CDC inputs')
