import fcntl,hashlib,json,os,subprocess,time
from pathlib import Path
root=Path('/root/discourse-vips-migration-01a0846e')
p=root/'memory-benchmarks/animation-final'
lock=(p/'collection.lock').open('w')
fcntl.flock(lock,fcntl.LOCK_EX)
rows=json.loads((p/'cases.json').read_text())
image='discourse/base:2.0.20260812-0036'
digest=json.loads(subprocess.check_output(['docker','image','inspect',image,'--format','{{json .RepoDigests}}']))
expected='discourse/base@sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5'
assert expected in digest
source={}
for bundle in {r['bundle'] for r in rows}:
 base=root/bundle
 source[bundle]={str(f.relative_to(base)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [*base.glob('lib/**/*.rb'),*base.glob('script/*'),base/'Gemfile',base/'Gemfile.lock'] if f.is_file()}
manifest={'image':image,'digest':expected,'source_sha256':source,'harness_sha256':{f:hashlib.sha256((p/f).read_bytes()).hexdigest() for f in ['run.rb','bootstrap.rb','cases.json','collect.py','Gemfile','Gemfile.lock']},'method':'median of 3 fresh-container cgroup memory.peak readings; each container includes Ruby harness boot, one warmup and five operations; total peak includes worker/process tree, charged file cache and kernel; MiB=bytes/1048576; existing timing from separate warm benchmarks','uid':1000,'cpu_limit':2,'memory':'2g','memory_swap':'3g'}
(p/'measurement-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
results=p/'raw.jsonl'
done=set()
if results.exists():
 for line in results.read_text().splitlines():
  r=json.loads(line);done.add((r['case_index'],r['backend'],r['replicate']))
for replicate in range(1,4):
 for index,row in enumerate(rows):
  backends=['imagemagick','libvips'] if replicate%2 else ['libvips','imagemagick']
  for backend in backends:
   if (index,backend,replicate) in done:continue
   command=['docker','run','--rm','--user','1000:1000','--cpus','2','--memory','2g','--memory-swap','3g','-v',f'{root/row["bundle"]}:/work:ro','-v',f'{p}:/probe:ro','-v',f'{root/"animation/gems"}:/gems:ro','--tmpfs','/work/tmp:uid=1000,gid=1000','-w','/work','-e','BUNDLE_PATH=/gems','-e','BUNDLE_FROZEN=true','-e','BUNDLE_GEMFILE=/probe/Gemfile','-e',f'CASE_INDEX={index}','-e',f'OPERATION={row["operation"]}','-e',f'BACKEND={backend}',image,'bundle','exec','ruby','/probe/run.rb']
   run=subprocess.run(command,text=True,capture_output=True,timeout=180)
   if run.returncode:
    (p/'failure.json').write_text(json.dumps({'command':command,'stdout':run.stdout,'stderr':run.stderr,'returncode':run.returncode},indent=2))
    raise RuntimeError(f'container failed {index}/{backend}: {run.stderr}')
   result=json.loads(run.stdout)
   result.update(replicate=replicate,pr=row['pr'],input_sha256=row['source_sha256'])
   if any(o['status']!='ok' for o in result['outcomes']):
    (p/'failure.json').write_text(json.dumps(result,indent=2))
    raise RuntimeError(f'operation failed {index}/{backend}: {result["outcomes"][0]}')
   with results.open('a') as f:f.write(json.dumps(result)+'\n')
   print(json.dumps({k:result[k] for k in ['case_index','operation','sample','backend','replicate','peak_mib']}),flush=True)
print('complete',flush=True)
