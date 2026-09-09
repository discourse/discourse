import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[3])
parser.add_argument('--jpeg-benchmark', type=Path, required=True)
parser.add_argument('--orientation-fix', default='056652b0cd0c71ceb2597bb2b2ab6a9e3dff3948')
args = parser.parse_args()
bundle = Path(__file__).resolve().parent

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def oriented_jpeg(source, orientation):
    data = source.read_bytes()
    if data[:2] != b'\xff\xd8':
        raise ValueError('expected a JPEG fixture')
    tag = struct.pack('<HHI', 0x0112, 3, 1) + struct.pack('<H', orientation) + b'\x00\x00'
    exif = b'Exif\x00\x00II' + struct.pack('<HIH', 42, 8, 1) + tag + struct.pack('<I', 0)
    output = data[:2] + b'\xff\xe1' + struct.pack('>H', len(exif) + 2) + exif
    offset = 2
    while offset < len(data):
        if data[offset] != 255:
            raise ValueError('invalid JPEG marker')
        marker = data[offset + 1]
        if marker in [0xda, 0xd9]:
            return output + data[offset:]
        length = int.from_bytes(data[offset + 2:offset + 4], 'big')
        segment = data[offset:offset + length + 2]
        if len(segment) != length + 2 or length < 2:
            raise ValueError('invalid JPEG metadata length')
        if not (marker == 0xe1 and segment[4:10] == b'Exif\x00\x00'):
            output += segment
        offset += length + 2
    raise ValueError('JPEG scan missing')

files = [
    'lib/discourse_vips.rb', 'lib/discourse_vips/client.rb',
    'lib/discourse_vips/worker_process.rb', 'lib/image_processing/instrumentation.rb',
    'lib/image_magick.rb', 'lib/discourse/safe_exec.rb', 'script/discourse_vips_worker',
]
for relative in files:
    target = bundle / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.repo / relative, target)
worker_path = bundle / 'script/discourse_vips_worker'
worker = worker_path.read_text()
fixed_worker = subprocess.check_output(['git', 'show', f'{args.orientation_fix}:script/discourse_vips_worker'], cwd=args.repo, text=True)
for method in ['auto_orient', 'load_image_for_orientation']:
    start_marker = f'    def self.{method}('
    end_marker = f'    private_class_method :{method}\n'
    start = fixed_worker.index(start_marker)
    end = fixed_worker.index(end_marker, start) + len(end_marker)
    replacement = fixed_worker[start:end]
    if start_marker in worker:
        start = worker.index(start_marker)
        end = worker.index(end_marker, start) + len(end_marker)
        worker = worker[:start] + replacement + worker[end:]
    else:
        worker = worker.replace('    def self.normalize_color', replacement + '\n    def self.normalize_color', 1)
worker_path.write_text(worker)
for name in ['Gemfile', 'Gemfile.lock']:
    shutil.copy2(args.jpeg_benchmark / name, bundle / name)
(bundle / 'tmp').mkdir(exist_ok=True)
(bundle / 'inputs').mkdir(exist_ok=True)
layouts = [
    [['red', 'green', 'blue'], ['cyan', 'magenta', 'yellow']],
    [['blue', 'green', 'red'], ['yellow', 'magenta', 'cyan']],
    [['yellow', 'magenta', 'cyan'], ['blue', 'green', 'red']],
    [['cyan', 'magenta', 'yellow'], ['red', 'green', 'blue']],
    [['red', 'cyan'], ['green', 'magenta'], ['blue', 'yellow']],
    [['cyan', 'red'], ['magenta', 'green'], ['yellow', 'blue']],
    [['yellow', 'blue'], ['magenta', 'green'], ['cyan', 'red']],
    [['blue', 'yellow'], ['green', 'magenta'], ['red', 'cyan']],
]
cases = []
source = args.repo / 'spec/fixtures/images/exif_orientation.jpg'
for orientation in range(1, 9):
    filename = f'grid-orientation-{orientation}.jpg'
    target = bundle / 'inputs' / filename
    target.write_bytes(oriented_jpeg(source, orientation))
    cases.append(dict(filename=filename, orientation=orientation, expected_layout=layouts[orientation - 1], source=str(source), source_sha256=sha(source), sha256=sha(target), recipe='replace EXIF APP1 with the orientation tag; preserve JPEG scan and all other segments'))
for filename, seed, orientation in [('photo-orientation-6.jpg', 'photo.jpg', 6), ('photo-icc-orientation-8.jpg', 'photo-profile.jpg', 8)]:
    source = args.jpeg_benchmark / 'inputs' / seed
    target = bundle / 'inputs' / filename
    target.write_bytes(oriented_jpeg(source, orientation))
    cases.append(dict(filename=filename, orientation=orientation, source=str(source), source_sha256=sha(source), sha256=sha(target), recipe='replace EXIF APP1 with the orientation tag; preserve JPEG scan and all other segments'))
cases.append(dict(filename='photo-progressive-orientation-6.jpg', orientation=6, generated_from='photo-orientation-6.jpg', recipe=['jpegtran', '-copy', 'all', '-progressive', '-outfile', 'inputs/photo-progressive-orientation-6.jpg', 'inputs/photo-orientation-6.jpg']))
(bundle / 'cases.json').write_text(json.dumps(cases, indent=2) + '\n')
manifest = dict(
    commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=args.repo, text=True).strip(),
    branch=subprocess.check_output(['git', 'branch', '--show-current'], cwd=args.repo, text=True).strip(),
    source_fix=dict(commit=args.orientation_fix, methods=['auto_orient', 'load_image_for_orientation']),
    source_status=subprocess.check_output(['git', 'status', '--short'], cwd=args.repo, text=True),
    production_image='discourse/base:2.0.20260812-0036',
    production_image_digest='sha256:837e8ed4b5916baa36856b842ad84fe262b6b1b5550701f8844b13cc7acad7a5',
    files={relative: sha(bundle / relative) for relative in files},
    bundle_files={name: sha(bundle / name) for name in ['Gemfile', 'Gemfile.lock', 'boot.rb', 'orientation_evidence.rb', 'prepare_bundle.py', 'cases.json']},
)
(bundle / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(dict(bundle=str(bundle), cases=len(cases), source_files=len(files))))
