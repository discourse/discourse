import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--commit', required=True)
parser.add_argument('--locked-runtime', type=Path, required=True)
args = parser.parse_args()
root = args.source.resolve()
bundle = Path(__file__).resolve().parent
commit = subprocess.check_output(['git', 'rev-parse', args.commit], cwd=root, text=True).strip()
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
if head != commit:
    raise ValueError('Source HEAD must match the explicit frozen commit')
source_paths = ['lib/discourse_vips.rb', 'lib/discourse_vips/client.rb', 'lib/discourse_vips/worker_process.rb', 'lib/discourse_vips/ico_image.rb', 'lib/discourse_vips/jpeg_quality.rb', 'lib/discourse_vips/jpeg_quality.LICENSE', 'lib/discourse_vips/jpeg_quality.NOTICE', 'lib/discourse/safe_exec.rb', 'lib/image_magick.rb', 'lib/image_processing/instrumentation.rb', 'script/discourse_vips_worker']
source = {}
for relative in source_paths:
    committed = subprocess.check_output(['git', 'show', f'{commit}:{relative}'], cwd=root)
    contents = (root / relative).read_bytes()
    if contents != committed:
        raise ValueError(f'Source differs from frozen commit: {relative}')
    source[relative] = hashlib.sha256(contents).hexdigest()
if (bundle / 'source-manifest.json').exists():
    raise ValueError('Source already frozen; preserve this bundle and use a new directory for another snapshot')
inputs = [
    ('jpeg-photo', 'jpeg', 'public/discourse-task/jpeg-benchmark/inputs/photo.jpg'),
    ('jpeg-grayscale', 'jpeg', 'public/discourse-task/jpeg-benchmark/inputs/gray.jpg'),
    ('jpeg-progressive', 'jpeg', 'public/discourse-task/orientation-benchmark/inputs/photo-progressive-orientation-6.jpg'),
    ('jpeg-matrix-source', 'jpeg', 'spec/fixtures/images/exif_orientation.jpg'),
    ('jpeg-logo', 'jpeg', 'spec/fixtures/images/logo.jpg'),
    ('png', 'png', 'spec/fixtures/images/smallest.png'),
    ('svg', 'svg', 'spec/fixtures/images/image.svg'),
    ('gif-static', 'gif', 'spec/fixtures/images/static.gif'),
    ('gif-animated', 'gif', 'spec/fixtures/images/animated.gif'),
    ('gif-tiny-animated', 'gif', 'spec/fixtures/images/tiny_animated.gif'),
    ('webp-static', 'webp', 'spec/fixtures/images/static.webp'),
    ('webp-animated', 'webp', 'spec/fixtures/images/animated.webp'),
    ('webp-lossless-static', 'webp', 'public/discourse-task/downsize/grid-lossless.webp'),
    ('webp-lossless-animated', 'webp', 'public/discourse-task/animated-quality-probe/lossless.webp'),
    ('avif-static', 'avif', 'spec/fixtures/images/static.avif'),
    ('avif-multipage', 'avif', 'spec/fixtures/images/multipage.avif'),
    ('ico-single', 'ico', 'spec/fixtures/images/smallest.ico'),
    ('ico-multi', 'ico', 'spec/fixtures/images/ico-last-png.ico'),
    ('jxl', 'jxl', 'spec/fixtures/images/dominant-color-float.jxl'),
]
records = []
for name, input_format, origin in inputs:
    path = root / origin
    contents = path.read_bytes()
    relative = f'inputs/{name}{path.suffix}'
    records.append({'name': name, 'input_format': input_format, 'path': relative, 'origin': origin, 'sha256': hashlib.sha256(contents).hexdigest(), 'bytes': len(contents)})
    if name == 'jxl':
        records[-1]['expected_outcome'] = 'unsupported'
        records[-1]['reason'] = 'Pinned production ImageMagick has no JXL delegate; the native quality operation intentionally rejects JXL and the Upload caller rescues to zero.'
inheritance_directory = root / 'public/discourse-task/webp-quality-inheritance-fixtures'
inheritance = json.loads((inheritance_directory / 'manifest.json').read_text())
inheritance_recipe = root / 'public/discourse-task/generate_webp_quality_inheritance.rb'
if hashlib.sha256(inheritance_recipe.read_bytes()).hexdigest() != inheritance['generator_sha256']:
    raise ValueError('WebP inheritance generator differs from its recorded manifest')
if len(inheritance['cases']) != 4:
    raise ValueError('Expected exactly four WebP inheritance cases')
for case in inheritance['cases']:
    path = inheritance_directory / case['filename']
    contents = path.read_bytes()
    if hashlib.sha256(contents).hexdigest() != case['sha256']:
        raise ValueError(f'WebP inheritance input changed: {path}')
    records.append({'name': f'webp-inheritance-{path.stem}', 'input_format': 'webp', 'path': f'inputs/webp-inheritance-{path.name}', 'origin': str(path.relative_to(root)), 'sha256': case['sha256'], 'bytes': len(contents), 'expected_quality_integer': case['expected_quality_integer'], 'generation_manifest': 'reference/webp-quality-inheritance-fixtures/manifest.json'})
for fragment in inheritance['fragments'].values():
    path = inheritance_directory / fragment['static_filename']
    if hashlib.sha256(path.read_bytes()).hexdigest() != fragment['static_sha256']:
        raise ValueError(f'WebP inheritance fragment changed: {path}')
for relative in source_paths:
    destination = bundle / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / relative, destination)
for record in records:
    destination = bundle / record['path']
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / record['origin'], destination)
for name in ['Gemfile', 'Gemfile.lock']:
    shutil.copy2(args.locked_runtime / name, bundle / name)
reference = bundle / 'reference/check_jpeg_quality.rb'
reference.parent.mkdir(parents=True, exist_ok=True)
shutil.copy2(root / 'public/discourse-task/check_jpeg_quality.rb', reference)
shutil.copy2(inheritance_recipe, bundle / 'reference/generate_webp_quality_inheritance.rb')
inheritance_destination = bundle / 'reference/webp-quality-inheritance-fixtures'
inheritance_destination.mkdir(parents=True, exist_ok=True)
inheritance_files = ['manifest.json', *[case['filename'] for case in inheritance['cases']], *[fragment['static_filename'] for fragment in inheritance['fragments'].values()]]
for name in inheritance_files:
    shutil.copy2(inheritance_directory / name, inheritance_destination / name)
reference_hashes = {str(path.relative_to(bundle)): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted((bundle / 'reference').rglob('*')) if path.is_file()}
manifest = {'commit': commit, 'files': source, 'inputs': records, 'dependency_source': str(args.locked_runtime.resolve()), 'dependency_hashes': {name: hashlib.sha256((bundle / name).read_bytes()).hexdigest() for name in ['Gemfile', 'Gemfile.lock']}, 'reference_hashes': reference_hashes, 'scope': 'Exact frozen production source; existing representative corpus plus bounded generated JPEG cases and four previously validated WebP inheritance animations. No benchmark runtime result is implied.'}
(bundle / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps({'commit': commit, 'source_files': len(source), 'existing_inputs': len(records), 'generated_representatives_pending': 3, 'matrix_expected': 500}))
