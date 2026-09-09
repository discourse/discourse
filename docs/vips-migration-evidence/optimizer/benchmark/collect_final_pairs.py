import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--jpeg-root', type=Path, default=Path('/benchmark-sources/jpeg'))
parser.add_argument('--geometry-root', type=Path, default=Path('/benchmark-sources/geometry'))
parser.add_argument('--orientation-root', type=Path, default=Path('/benchmark-sources/orientation'))
parser.add_argument('--threshold-root', type=Path)
parser.add_argument('--mount-prefix', default='/benchmark-sources')
parser.add_argument('--threshold-role', default='optimizer/threshold-final-c63')
parser.add_argument('--output', type=Path, default=Path('pairs-final.json'))
parser.add_argument('--allow-pending-orientation', action='store_true')
parser.add_argument('--threshold-only', action='store_true')
args = parser.parse_args()
if args.threshold_only and not args.threshold_root:
    parser.error('--threshold-only requires --threshold-root')
if args.output.exists() or args.output.with_suffix('.audit.json').exists():
    raise ValueError('Use a fresh output manifest path; existing manifests are preserved')
pairs = []
audit = {'reports': [], 'excluded': [], 'pending': [], 'png_threshold_bytes': 500000}


def read_report(*, root, filename, role):
    path = root / filename
    report = json.loads(path.read_text())
    audit['reports'].append({'path': f'{args.mount_prefix}/{role}/{filename}', 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'source': report.get('source')})
    return report


def add_pair(*, operation, name, root, role, paths, hashes, provenance):
    pair = {'operation': operation, 'name': name, 'input_sha256': hashes, 'provenance': provenance, 'input_bytes': {}}
    for backend, relative in paths.items():
        path = root / relative
        if hashlib.sha256(path.read_bytes()).hexdigest() != hashes[backend]:
            raise ValueError(f'Output checksum mismatch: {path}')
        pair[backend] = f'{args.mount_prefix}/{role}/{relative}'
        pair['input_bytes'][backend] = path.stat().st_size
    if set(paths) != {'imagemagick', 'libvips'}:
        raise ValueError(f'Missing paired backend: {name}')
    pairs.append(pair)


if not args.threshold_only:
    for role, root, filename in [('jpeg', args.jpeg_root, 'final-selective.json'), ('orientation', args.orientation_root, 'final-selective-corrected.json')]:
        if role == 'orientation' and not (root / filename).exists() and args.allow_pending_orientation:
            audit['pending'].append({'operation': role, 'report': filename})
            continue
        report = read_report(root=root, filename=filename, role=role)
        for sample in report['samples']:
            name = sample['filename']
            hashes = sample.get('output_sha256', {})
            if set(hashes) != {'imagemagick', 'libvips'}:
                audit['excluded'].append({'operation': role, 'name': name, 'reason': 'No successful hashed pair', 'outcome': sample.get('single_stress_attempt', sample)})
                continue
            paths = {}
            for backend in hashes:
                candidates = [path for path in (root / 'outputs-final-selective').glob(f'{name}-{backend}.*') if not path.name.endswith('-decoded.png') and hashlib.sha256(path.read_bytes()).hexdigest() == hashes[backend]]
                if len(candidates) != 1:
                    raise ValueError(f'Expected one exact encoded output: {role}/{name}/{backend}')
                paths[backend] = str(candidates[0].relative_to(root))
            add_pair(operation=role, name=name, root=root, role=role, paths=paths, hashes=hashes, provenance={'report': filename, 'source': report.get('source')})

    for operation in ['downsize', 'crop', 'resize']:
        names = [f'{operation}-final-selective.json'] if operation != 'resize' else ['resize-final-white.json']
        names += ['downsize-svg-white.json'] if operation == 'downsize' else ['crop-svg-white-false.json', 'crop-svg-white-true.json'] if operation == 'crop' else []
        selected = {}
        for filename in names:
            report = read_report(root=args.geometry_root, filename=filename, role='geometry')
            for sample in report['samples']:
                if sample['name'] in selected:
                    audit['excluded'].append({'operation': operation, 'name': sample['name'], 'report': selected[sample['name']][1], 'reason': 'Superseded SVG row; use corrected white-background report'})
                selected[sample['name']] = (sample, filename, report['source'])
        for name, (sample, filename, source) in selected.items():
            if not sample.get('eligible_for_paired_timing'):
                audit['excluded'].append({'operation': operation, 'name': name, 'report': filename, 'reason': 'No successful raw transform pair', 'outcome': sample['initial_validation']})
                continue
            outputs = sample['outputs']
            add_pair(operation=operation, name=name, root=args.geometry_root, role='geometry', paths={b: o['path'] for b, o in outputs.items()}, hashes={b: o['sha256'] for b, o in outputs.items()}, provenance={'report': filename, 'source': source, 'transform_strip_metadata': sample['parameters']['strip_metadata']})

if args.threshold_root:
    report = read_report(root=args.threshold_root, filename='threshold-results.json', role=args.threshold_role)
    if len(report['samples']) != 5:
        raise ValueError('Threshold report is incomplete; expected five pairs')
    for sample in report['samples']:
        if sample['status'] != 'ok':
            raise ValueError(f'Threshold preparation failed: {sample}')
        outputs = sample['outputs']
        add_pair(operation=sample['operation'], name=sample['name'], root=args.threshold_root, role=args.threshold_role, paths={b: o['path'] for b, o in outputs.items()}, hashes={b: o['sha256'] for b, o in outputs.items()}, provenance={'report': 'threshold-results.json', 'source': report['source'], 'transform_strip_metadata': sample.get('strip_metadata'), 'supplemental': 'Deterministic genuine geometry output; no transform timing claim'})

identities = [(pair['operation'], pair['name']) for pair in pairs]
if len(identities) != len(set(identities)):
    raise ValueError('Duplicate operation/case identity')
audit['counts'] = {operation: sum(pair['operation'] == operation for pair in pairs) for operation in sorted({pair['operation'] for pair in pairs})}
audit['png_at_or_above_threshold'] = [{'operation': pair['operation'], 'name': pair['name'], 'backend': backend, 'bytes': pair['input_bytes'][backend], 'path': pair[backend]} for pair in pairs for backend in ['imagemagick', 'libvips'] if pair[backend].lower().endswith('.png') and pair['input_bytes'][backend] >= 500000]
audit['scope'] = 'Final encoded pairs only. No decoded previews, cold files, historical duplicate rows, or failed transform outputs. Existing earlier optimizer results remain separate.'
args.output.write_text(json.dumps(pairs, indent=2) + '\n')
args.output.with_suffix('.audit.json').write_text(json.dumps(audit, indent=2) + '\n')
print(json.dumps({'pairs': len(pairs), 'counts': audit['counts'], 'excluded': len(audit['excluded']), 'pending': audit['pending'], 'large_png_outputs': len(audit['png_at_or_above_threshold'])}))
