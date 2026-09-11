import hashlib,json,statistics
from pathlib import Path
p=Path(__file__).parent
cases=json.loads((p/'cases.json').read_text())
records=[json.loads(line) for line in (p/'raw.jsonl').read_text().splitlines()]
assert len(records)==len(cases)*6,(len(records),len(cases)*6)
summary=[]
for index,row in enumerate(cases):
 output=dict(row)
 output['memory']={}
 for backend in ['imagemagick','libvips']:
  values=sorted([r for r in records if r['case_index']==index and r['backend']==backend],key=lambda r:r['replicate'])
  assert [r['replicate'] for r in values]==[1,2,3]
  assert all(r['uid']==1000 and all(o['status']=='ok' for o in r['outcomes']) for r in values)
  peaks=[r['peak_bytes'] for r in values]
  output['memory'][backend]={'median_peak_mib':statistics.median(peaks)/1048576,'peak_bytes_trials':peaks,'peak_mib_trials':[n/1048576 for n in peaks]}
 summary.append(output)
(p/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
lines=['| PR | Operation | Sample | IM median ms | libvips median ms | IM peak MiB | libvips peak MiB |','| --- | --- | --- | ---: | ---: | ---: | ---: |']
for r in summary:
 lines.append(f'| {r["pr"]} | {r["operation"]} | {r["sample"]} | {r["imagemagick_median_ms"]:.2f} | {r["libvips_median_ms"]:.2f} | {r["memory"]["imagemagick"]["median_peak_mib"]:.2f} | {r["memory"]["libvips"]["median_peak_mib"]:.2f} |')
(p/'summary.md').write_text('\n'.join(lines)+'\n')
print(f'{len(summary)} cases across {len(set(r["pr"] for r in summary))} PRs; {len(records)} successful containers')
