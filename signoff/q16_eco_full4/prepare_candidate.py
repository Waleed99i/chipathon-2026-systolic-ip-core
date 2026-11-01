#!/usr/bin/env python3
"""Preserve and stage the reviewed A34 candidate. No EDA, commit, or push.

Run from /home/rumali/openlane_project/a34-rtl-fix-pd.
The exact reviewed source/report hashes are embedded at delivery time.
"""
import datetime as dt
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path('/home/rumali/openlane_project/a34-rtl-fix-pd')
BASE = 'e632192eab6061a91752ef0798ed6a546c1ba39b'
BRANCH = 'a34-rtl-fix-pd'
TAG = 'A34_Q16_ECO_FULL4_20261015_160735'
DIAG = Path('verification_results/physical-eco-yoy1al0x')
REGRESSION = Path('verification_results/q16-regression-un410tfo')
EVIDENCE = Path('signoff/q16_eco_full4')
MODIFIED = {
    'librelane/chip_core_macro.yaml', 'src/rtl/counter.v',
    'src/rtl/input_datapath.v', 'src/rtl/fp16_to_q16_16_approximate_mac.v',
}
NEW_RTL = 'src/rtl/fp16_to_q16_16.v'
# Filled from the reviewed report archive; not from files on the user's laptop.
EXPECTED_REPORTS = {'a34_apply_eco.py': '4cf28ab7f536986de18b3412832ee2ba66331403a23a68329a3ac8ea6e351e79',
 'apply.log': 'd686ba0942f94f494214a644b1fb5029ad0eaa1354e4e11e1e169306eeb17e79',
 'apply_seven_cells.tcl': 'f29b1afc1fe824f8ff1101dcbd1626d1d3a77cc967ef3aa4154dba535b9f7910',
 'check_final_eco.tcl': 'c7c74cc1ad41a039026719137d65026ecc1c58bb30f4c1f6472312794ae8a9bd',
 'eco_run_manifest.json': 'd65c44395d8484089e2f0951d3e79dc337357201a29cc92a5601678c358e6e44',
 'eco_state_in.json': '9ba1c6f070c228dca67c7697add1adfbfbcce07cbd60ec891c93e9febecbb9b2',
 'eco_summary.txt': '4d636405c13fcd500f65695eec58ecbbb7e153ce3d112e4b0625be125bc89b0b',
 'final_odb_check.log': '8115e48e29f74dd0696d01cab9213b3e164a6005667c2f4845fe37d1d5fd3443',
 'final_sha256.json': 'ab498e7c6169e8b56e50efacfbc1b883652929561a07b3c7fbe380bcd519d827',
 'physical_flow.log': '2a3e387e3075e2ba66c54cc0b0eb78dd1f9c198c68f3030d183f685415a00c5b',
 'probe_provenance.json': '9fdab4ad088570e525d1e6e5646fb5d0710f1c60fd066e16930fab9887519e4a',
 'run_reports/01-openroad-detailedplacement/config.json': '779460711977fb7b5dd1619dee728acb7fc09c94636513645f10fe31e13a6740',
 'run_reports/19-openroad-stapostpnr/config.json': '7fd1e0cf0f0745addb947a601e44fb9706f424092a431b68ed2de1d46550323c',
 'run_reports/19-openroad-stapostpnr/max_ff_n40C_5v50/checks.rpt': '635811807427fda092bc93bb5778ca5ca00dc58c2d53a7eccd895e7667192875',
 'run_reports/19-openroad-stapostpnr/max_ss_125C_4v50/checks.rpt': '4df56438676d38f34d34aad8240289afc416d33c1a5f8efca651ddc07d699933',
 'run_reports/19-openroad-stapostpnr/max_tt_025C_5v00/checks.rpt': '2985f103108aaaa6cae864b944e940cd4c27dbfda7201d1a58c7827ff1786ca9',
 'run_reports/19-openroad-stapostpnr/min_ff_n40C_5v50/checks.rpt': '753cc8e8a467946bf60cd12ab1ace0ded934bf86a040a7198e34e74d6c80e36a',
 'run_reports/19-openroad-stapostpnr/min_ss_125C_4v50/checks.rpt': '5c282dd7738e7b685eefff103b8dcc2d9f9cf366496fcf0c5c28f27ea5e6d32d',
 'run_reports/19-openroad-stapostpnr/min_tt_025C_5v00/checks.rpt': '1f97dce03495e9592c593a4a36d1cd73a7e7bb05afb04322fe4ae22c08f0ae54',
 'run_reports/19-openroad-stapostpnr/nom_ff_n40C_5v50/checks.rpt': 'ae6b40c03b8ab1f0d21e6f881a9a1fa8844f36b59dcf65f48a8eb45220ca8544',
 'run_reports/19-openroad-stapostpnr/nom_ss_125C_4v50/checks.rpt': '5afb1af71bc6d69cedd641ef445ae76077c794637c4bd59f00076bee7673eec1',
 'run_reports/19-openroad-stapostpnr/nom_tt_025C_5v00/checks.rpt': 'cd625bb48bb5902cb5afca314fa6838b9757b8cb421c1c0909becab44f9144b7',
 'run_reports/19-openroad-stapostpnr/summary.rpt': '415b18579992ff8ae219aab9b14af7eea99a6ed63566314e13f418428d9393bf',
 'run_reports/34-netgen-lvs/netgen-lvs.log': '7f104bfa5cfda96d9317ce38ee60b45a00334901b137cd0b945f40732a586858',
 'run_reports/34-netgen-lvs/reports/lvs.netgen.rpt': '6018e462c97f6cc1442e46336bebccb06c644fac1aa91c0b447fcb56a84b75cb',
 'run_reports/final/metrics.csv': '2c80613c92b437cc01e6fcef517929034870bbd5f0fa02a88b25ee971cddfffd',
 'run_reports/final/metrics.json': '639f069154581f07a115c21c3ea3623c412c1d1a649e60a5d3fda9ad6a0d2bd4'}
EXPECTED_FINAL = {'def/chip_core.def': '731cdb6dddb5b3ad2f84d9cf2c4f753ee0b1c9ce6ae2cb184f4fa8dded9007e9',
 'gds/chip_core.gds': '76091ccb1052a45195f3b30766380e44a60ad4da4ac7ed8a1dac7dec226a87e3',
 'odb/chip_core.odb': 'de97f7be6582627982561d2d7b60db82b9c3bbcf1bd2d892a1d530a1e62ced4f',
 'pnl/chip_core.pnl.v': '42821194c1447902f4022622f8daba5143bb3bd526fd32fb5e811a8fcb7a5410'}


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], text=True).strip()


def check_file(path, digest):
    require(path.is_file(), f'Missing file: {path}')
    require(sha(path) == digest, f'Hash differs from the reviewed result: {path}')


def files_under(directory):
    """Enumerate ordinary directories and files; dereference file symlinks."""
    require(directory.is_dir(), f'Missing directory: {directory}')
    result = []
    for parent, dirs, files in os.walk(directory):
        parent = Path(parent)
        for name in dirs:
            require(not (parent / name).is_symlink(),
                    f'Directory symlink needs review before backup: {parent / name}')
        for name in files:
            p = parent / name
            require(p.is_file(), f'Non-regular or broken file: {p}')
            require(p.resolve().is_relative_to(ROOT.resolve()),
                    f'Backup source resolves outside this worktree: {p}')
            result.append(p)
    return sorted(result)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def backup_archive(archive, entries, generated):
    hashes = {name: sha(path) for name, path in entries.items()}
    require(len(entries) == len(set(entries)), 'Duplicate backup names.')
    require(not set(entries).intersection(generated), 'Backup name collision.')
    payloads = {k: v.encode() for k, v in generated.items()}
    hashes.update({k: hashlib.sha256(v).hexdigest() for k, v in payloads.items()})
    payloads['BACKUP_SHA256.json'] = (json.dumps(hashes, indent=2) + '\n').encode()
    print(f'Backing up {len(entries)} files; this does not run physical design.', flush=True)
    with tarfile.open(archive, 'w:gz', compresslevel=1, dereference=True) as tar:
        for name, path in entries.items():
            tar.add(path, arcname=name, recursive=False)
        for name, data in payloads.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o644
            tar.addfile(info, io.BytesIO(data))
    # Verify readable archive contents against the source hashes before replacing files.
    print('Checking backup integrity...', flush=True)
    seen = set()
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar:
            if member.name == 'BACKUP_SHA256.json':
                continue
            require(member.isfile() and member.name in hashes,
                    f'Unexpected archive member: {member.name}')
            h = hashlib.sha256()
            f = tar.extractfile(member)
            for block in iter(lambda: f.read(1024 * 1024), b''):
                h.update(block)
            require(h.hexdigest() == hashes[member.name],
                    f'Backup verification failed: {member.name}')
            seen.add(member.name)
    require(seen == set(hashes), 'Backup is incomplete.')
    archive.with_name(archive.name + '.sha256').write_text(sha(archive) + '  ' + archive.name + '\n')


def main():
    require(Path.cwd().resolve() == ROOT.resolve(),
            'Run from ~/openlane_project/a34-rtl-fix-pd.')
    require(git('rev-parse', '--show-toplevel') == str(ROOT), 'Unexpected Git worktree.')
    require(git('branch', '--show-current') == BRANCH, 'Wrong branch; nothing changed.')
    require(git('rev-parse', 'HEAD') == BASE, 'Branch HEAD changed; review it before packaging.')
    require(not git('diff', '--cached', '--name-only'), 'Index is not empty; review staged files first.')
    dirty = set(git('diff', '--name-only').splitlines())
    require(dirty == MODIFIED, f'Unexpected tracked-file changes: {sorted(dirty)}')
    require(not (ROOT / EVIDENCE).exists(), f'{EVIDENCE} already exists; do not overwrite it.')
    require(EXPECTED_REPORTS and EXPECTED_FINAL, 'Missing embedded review hashes.')
    diag, run = ROOT / DIAG, ROOT / 'librelane/runs' / TAG
    final = run / 'final'
    for rel, digest in EXPECTED_REPORTS.items():
        check_file(diag / rel, digest)
    manifest = json.loads((diag / 'eco_run_manifest.json').read_text())
    require(manifest['run'] == str(run), 'Run provenance does not match the selected run.')
    for name, digest in manifest['protected_sha256'].items():
        check_file(Path(name), digest)
    require(json.loads((diag / 'final_sha256.json').read_text()) == EXPECTED_FINAL,
            'Recorded final hashes differ from the reviewed artifact set.')
    for rel, digest in EXPECTED_FINAL.items():
        check_file(final / rel, digest)
    require('LOCAL ECO CHECKS PASS' in (diag / 'eco_summary.txt').read_text(),
            'Successful final check record is missing.')

    # Match reports about to be installed with the actual run reports, too.
    for rel, digest in EXPECTED_REPORTS.items():
        if rel.startswith('run_reports/'):
            check_file(run / rel.removeprefix('run_reports/'), digest)

    copies = {
        'gds/chip_core.gds': final / 'gds/chip_core.gds',
        'verilog/gl/chip_core.pnl.v': final / 'pnl/chip_core.pnl.v',
        'signoff/lvs/lvs.report': run / '34-netgen-lvs/reports/lvs.netgen.rpt',
        'signoff/lvs/netgen-lvs.log': run / '34-netgen-lvs/netgen-lvs.log',
    }
    for rel in copies:
        p = ROOT / rel
        require(p.is_file() and not p.is_symlink(), f'Unexpected destination file: {p}')
        git('ls-files', '--error-unmatch', '--', rel)
        require(not git('diff', 'HEAD', '--', rel), f'Destination has local edits: {rel}')
    source_names = git('ls-files', '--', 'src', 'librelane/chip_core_macro.yaml',
                       'librelane/chip_core.sdc', 'librelane/A34_ACE_scaled.def',
                       'librelane/pdn_cfg_a34.tcl', 'info.yaml', 'lvs_config.json',
                       'shell.nix', 'flake.nix', 'flake.lock').splitlines()
    source_names.append(NEW_RTL)
    require((ROOT / NEW_RTL).is_file(), 'New converter missing.')
    for name in ['librelane/chip_core.sdc', 'librelane/A34_ACE_scaled.def', 'librelane/pdn_cfg_a34.tcl']:
        require(name in source_names, f'Expected tracked configuration is missing: {name}')

    state = json.loads((diag / 'eco_state_in.json').read_text())
    checkpoints = {k: Path(state[k]) for k in ('odb', 'json_h', 'vh')}
    checkpoints['pre_eco_state'] = Path(manifest['initial_checkpoint'])
    pre_state = json.loads(checkpoints['pre_eco_state'].read_text())
    checkpoints['pre_eco_odb'] = Path(pre_state['odb'])
    for p in checkpoints.values():
        require(p.is_file() and p.resolve().is_relative_to(ROOT.resolve()),
                f'Missing or unexpected checkpoint: {p}')
    reg_files = files_under(ROOT / REGRESSION)
    required_reg = {'summary.json', 'cases.json', 'wrapper_tb.sv', 'converter_tb.sv',
                    'converter_expected.hex', 'wrapper_simulation.log', 'converter_simulation.log'}
    require(required_reg.issubset({p.name for p in reg_files}), 'Regression evidence is incomplete.')
    regression_summary = json.loads((ROOT / REGRESSION / 'summary.json').read_text())
    require(regression_summary.get('passed') is True, 'Regression summary does not record a pass.')
    for rel, digest in regression_summary['files_sha256'].items():
        # The source list/PD tuning changed after this pre-PD functional regression.
        if rel != 'librelane/chip_core_macro.yaml':
            p = ROOT / rel
            require(p.resolve().is_relative_to(ROOT.resolve()), 'Unexpected regression source path.')
            check_file(p, digest)
    final_files = files_under(final)

    # Build a local preservation bundle outside Git. It includes full final views,
    # original destination files and the checkpoint/header dependencies.
    entries = {'source/' + n: ROOT / n for n in source_names}
    entries.update({'final/' + p.relative_to(final).as_posix(): p for p in final_files})
    entries.update({'evidence/' + rel: diag / rel for rel in EXPECTED_REPORTS})
    entries.update({'checkpoints/' + key + '/' + p.name: p for key, p in checkpoints.items()})
    entries.update({'rtl_regression/' + p.relative_to(ROOT / REGRESSION).as_posix(): p for p in reg_files})
    entries.update({'previous_candidate_paths/' + rel: ROOT / rel for rel in copies})
    entries['prepare_candidate.py'] = Path(__file__).resolve()
    checkpoint_map = {key: 'checkpoints/' + key + '/' + p.name for key, p in checkpoints.items()}
    stamp = dt.datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_parent = ROOT.parent / 'a34_candidate_backups'
    backup_parent.mkdir(exist_ok=True)
    archive = backup_parent / f'{TAG}_candidate_{stamp}.tar.gz'
    require(not archive.exists(), f'Backup already exists: {archive}')
    total = sum(p.stat().st_size for p in entries.values())
    require(shutil.disk_usage(backup_parent).free > total * 2 + 256 * 1024**2,
            'Not enough free space for a safe backup; no candidate outputs changed.')
    print('PREFLIGHT PASS: reviewed source, report and final artifact hashes match.', flush=True)
    generated = {
        'CHECKPOINT_MAP.json': json.dumps(checkpoint_map, indent=2) + '\n',
        'README.txt': (
            'A34 corrected-RTL candidate preservation bundle.\n'
            'Full final views, reviewed evidence, RTL/configuration, functional-regression\n'
            'files and pre/post-ECO checkpoint inputs are included. PDK and Nix store are external.\n'
            'ECO scripts/state files retain original absolute laptop paths; CHECKPOINT_MAP.json\n'
            'identifies archived database/header files for relocation. Do not execute blindly.\n'
            'A YAML-only fresh flow does not replay the seven explicit cell changes.\n'
            'Original submitted main was not changed. Integrated approval and pad-aware IR/EM\n'
            'remain outside local signoff. This is a same-disk backup, not an off-device backup.\n'
        ),
    }
    backup_archive(archive, entries, generated)
    print('BACKUP VERIFIED:', archive, flush=True)

    # Prepare the modest report tree before touching tracked output paths.
    prepared = Path(tempfile.mkdtemp(prefix='a34-stage-', dir=backup_parent))
    evidence = prepared / 'evidence'
    evidence.mkdir()
    for rel in EXPECTED_REPORTS:
        target = evidence / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(diag / rel, target)
    for p in reg_files:
        if p.suffix not in {'.vvp', '.vcd', '.fst'}:
            target = evidence / 'rtl_regression' / p.relative_to(ROOT / REGRESSION)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
    shutil.copy2(Path(__file__), evidence / 'prepare_candidate.py')
    write_json(evidence / 'candidate_record.json', {
        'branch': BRANCH, 'base_commit': BASE, 'run': TAG,
        'backup': str(archive), 'final_sha256': EXPECTED_FINAL,
        'clock_period_ns': 45, 'worst_setup_slack_ns': 0.5498535116188729,
        'worst_hold_slack_ns': 0.09115441992566169,
        'scope': 'Reviewed local ECO signoff. No integrated-chip approval or pad-aware IR/EM claim.',
    })
    (evidence / 'README.md').write_text(
        '# A34 corrected-RTL candidate: local ECO signoff\n\n'
        f'Run: `{TAG}`. Clock target: 45 ns.\n\n'
        'All nine corners report zero setup, hold, slew, capacitance and fanout violations.\n'
        'Worst setup slack: +0.549854 ns; worst hold slack: +0.091154 ns.\n'
        'Routing/Magic/KLayout DRC, LVS and antenna checks pass. Final power connectivity\n'
        'and boundary/ring checks pass. See detailed reports and recorded artifact hashes.\n\n'
        'This layout includes seven explicit cell-master changes followed by legalization,\n'
        'rerouting, new extraction and signoff. YAML alone does not replay that ECO.\n'
        'The archived scripts and checkpoint records contain the original absolute paths.\n'
        'The separate preservation bundle includes the pre/post-ECO ODB and required headers.\n'
        'Keep FULL2, FULL3, FULL4 and diagnostics until relocation/reproduction is arranged.\n\n'
        'The powered netlist in verilog/gl and GDS in gds belong to this same final run.\n'
        'Earlier general signoff directories may describe the prior implementation;\n'
        'this directory and the updated signoff/lvs files are this candidate\'s evidence.\n\n'
        'Functional regression evidence is copied without rerunning the tests. It covers\n'
        '65,536 converter encodings and 22 wrapper cases (20 exact, two approximate-model).\n'
        'Reset per matrix, approximate arithmetic, continuing internal activity and finite\n'
        'Q16.16/accumulator range remain limitations. No formal RTL equivalence was run.\n'
        'Integrated-chip checks, organizer acceptance and pad-aware IR/EM remain separate.\n'
    )
    # Only the candidate worktree is written; no commands operate on main.
    require(git('branch', '--show-current') == BRANCH and git('rev-parse', 'HEAD') == BASE,
            'Git state changed during backup; stopping before output copies.')
    require(not git('diff', '--cached', '--name-only'), 'Index changed during backup.')
    for rel, source in copies.items():
        shutil.copy2(source, ROOT / rel)
        require(sha(ROOT / rel) == sha(source), f'Copy verification failed: {rel}')
    shutil.copytree(evidence, ROOT / EVIDENCE)
    stage = sorted(MODIFIED) + [NEW_RTL] + list(copies)
    git('add', '--', *stage)
    # This narrow, freshly generated evidence directory contains metrics beneath
    # a directory named final/, which the repository's general ignore rule excludes.
    git('add', '-f', '--', EVIDENCE.as_posix())
    evidence_staged = set(git('diff', '--cached', '--name-only', '--', EVIDENCE.as_posix()).splitlines())
    expected_evidence = {(EVIDENCE / p.relative_to(evidence)).as_posix()
                         for p in evidence.rglob('*') if p.is_file()}
    require(evidence_staged == expected_evidence, 'Not all candidate evidence files were staged.')
    print('\nCANDIDATE PREPARED AND STAGED. No commit or push performed.')
    print('Backup:', archive)
    print('Branch:', git('branch', '--show-current'))
    print('\nSTAGED SUMMARY:\n' + git('diff', '--cached', '--stat'))
    print('\nWORKTREE STATUS:\n' + git('status', '--short'))
    print('\nKeep all run directories for now. Share this output before committing.')


if __name__ == '__main__':
    try:
        main()
    except (Exception, KeyboardInterrupt) as exc:
        print(f'\nSTOP: {exc}', file=sys.stderr)
        print('No commit or push was attempted. If copying/staging already started, keep the backup\n'
              'and share this message together with git status --short. Do not delete any runs.', file=sys.stderr)
        sys.exit(1)
