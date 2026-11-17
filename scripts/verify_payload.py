"""Check the public snapshot against its content checksum manifest."""
from pathlib import Path
import hashlib
R=Path(__file__).resolve().parents[1];count=0
for line in (R/'SHA256SUMS.txt').read_text().splitlines():
 expected,rel=line.split('  ',1);p=R/rel
 if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=expected:raise SystemExit('Mismatch: '+rel)
 count+=1
print(f'Verified {count} repository payload hashes')
