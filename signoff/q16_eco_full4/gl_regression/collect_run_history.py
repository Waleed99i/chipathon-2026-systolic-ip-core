"""Read exact FULL1/FULL2/FULL3/FULL4 history; no design, Git or run changes."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[3]
run_names = ['A34_Q16_FIX_FULL1', 'A34_Q16_FIX_FULL2', 'A34_Q16_FIX_FULL3',
             'A34_Q16_ECO_FULL4_20261015_160735']
metrics = ['timing__setup__ws', 'timing__hold__ws', 'timing__setup_vio__count',
           'timing__hold_vio__count', 'design__max_slew_violation__count',
           'design__max_cap_violation__count', 'design__max_fanout_violation__count',
           'route__drc_errors', 'magic__drc_error__count', 'klayout__drc_error__count',
           'design__lvs_error__count', 'antenna__violating__nets']
settings = ['CLOCK_PERIOD', 'PNR_CORNERS', 'RSZ_CORNERS', 'CTS_CORNERS',
            'CTS_SINK_CLUSTERING_SIZE', 'CTS_DISTANCE_BETWEEN_BUFFERS',
            'CTS_SINK_BUFFER_MAX_CAP_DERATE_PCT', 'CTS_CLK_MAX_WIRE_LENGTH',
            'GRT_DESIGN_REPAIR_MAX_SLEW_PCT', 'GRT_DESIGN_REPAIR_MAX_CAP_PCT',
            'GRT_RESIZER_SETUP_SLACK_MARGIN', 'GRT_RESIZER_HOLD_SLACK_MARGIN',
            'GRT_RESIZER_ALLOW_SETUP_VIOS', 'STA_CORNERS', 'STA_EXTRA_CORNER_TCL_FILE']
for name in run_names:
    run = repo/'librelane/runs'/name
    print('\n===', name, '===')
    if not run.is_dir():
        print('RUN DIRECTORY MISSING'); continue
    m = run/'final/metrics.json'
    if m.is_file():
        data = json.loads(m.read_text())
        print('FINAL METRICS:', json.dumps({k:data.get(k, '<absent>') for k in metrics}, sort_keys=True))
    else:
        print('NO FINAL METRICS: do not describe this run as completed signoff.')
    for basename in ('resolved.json', 'config.json'):
        p=run/basename
        if p.is_file():
            data=json.loads(p.read_text())
            print('ROOT CONFIG:',p.relative_to(repo))
            print(json.dumps({k:data[k] for k in settings if k in data},sort_keys=True))
    for suffix in ('openroad-cts','openroad-repairdesignpostgrt',
                   'openroad-resizertimingpostgrt','openroad-stapostpnr'):
        paths=sorted(run.glob(f'*-{suffix}/config.json'))
        if not paths:
            print(suffix+': no saved step config in this run (may be inherited or skipped).')
        for p in paths:
            data=json.loads(p.read_text())
            print('STEP CONFIG:',p.relative_to(repo))
            print(json.dumps({k:data[k] for k in settings if k in data},sort_keys=True))
    inputs=sorted(run.glob('*/state_in.json'))
    if inputs:
        # Numeric step order matters for resumed runs.
        p=min(inputs,key=lambda p:int(p.parent.name.split('-',1)[0]))
        state=json.loads(p.read_text())
        print('FIRST SAVED STEP INPUT:',p.relative_to(repo))
        print(json.dumps({k:state.get(k) for k in ('odb','json_h','vh')},sort_keys=True))
print('\nScope: local saved files only; no assumptions from missing root configs or shell history.')
