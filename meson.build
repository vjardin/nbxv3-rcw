# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2026 Free Mobile - Vincent Jardin
#
# Nodebox v3 RCW sources -- one build for every carrier variant.
#
# There is no compiler here: each target is a .rcw source run through
# `qoriq-rcw` to produce the RCW+PBI binary the LX2160A boot Service Processor

project(
  'nbxv3-rcw',
  version: '0.1.0',
  license: 'BSD-3-Clause',
  meson_version: '>=0.60.0',
)

fs = import('fs')
srcroot = meson.current_source_dir()

# Locate qoriq-rcw and the two include roots.
qoriq_rcw_path = get_option('qoriq-rcw-path')
if qoriq_rcw_path == ''
  qoriq_rcw_path = srcroot / '..' / 'qoriq-rcw'
endif

# Prefer the in-tree build, then an installed qoriq-rcw on PATH.
qoriq_rcw = find_program(qoriq_rcw_path / 'build' / 'qoriq-rcw',
                         'qoriq-rcw',
                         required: true)

rcw_data_dir = get_option('qoriq-rcw-data')
if rcw_data_dir == ''
  rcw_data_dir = qoriq_rcw_path / 'data'
endif

rcw_ref_dir = get_option('rcw-ref-dir')
if rcw_ref_dir == ''
  rcw_ref_dir = srcroot / '..' / 'rcw'
endif
rcw_errata_dir = rcw_ref_dir / 'lx2160asi'

# Local shadow of the upstream errata.
rcw_local_errata_dir = srcroot / 'lx2160asi'

foreach d : [rcw_data_dir, rcw_errata_dir]
  if not fs.is_dir(d)
    error('include root not found: ' + d + '''
  Pass -Dqoriq-rcw-data= / -Drcw-ref-dir= if the sibling layout differs.''')
  endif
endforeach

rcw_shadow_errata = [
  'serdes_prtcl.rcw',
  'a011270.rcw',
  'a050234.rcw',
  'a050426.rcw',
]

rcw_common = files(
  'rcw_nbxv3_common.rcwi',
  'rcw_nbxv3_carrier.rcwi',
  'uart1_version.rcwi',
)
foreach f : rcw_shadow_errata
  rcw_common += files('lx2160asi' / f)
endforeach

# The boards
rcw_variants = [
  {
    'name': 'nbv30',
    'src': 'rcw_nbxv30x31_2200_700_2400_13_7_3.rcw',
    'desc': 'NBV30 / NBV31 carrier',
  },
  {
    'name': 'nbv32',
    'src': 'rcw_nbxv32_2200_700_2400_13_7_3.rcw',
    'desc': 'NBV32 carrier (4x25G SerDes split)',
  },
  {
    'name': 'standalone',
    'src': 'rcw_nbxv3_withoutIOs_nor.rcw',
    'desc': 'CPU module standalone, no PCIe / no Ethernet IO',
  },
]

size_check = find_program('tools/check-pbl-size.sh')

rcw_bins = []
variant_names = []
foreach v : rcw_variants
  variant_names += v['name']
  out = fs.replace_suffix(v['src'], '.bin')
  bin = custom_target(
    v['name'],
    input: files(v['src']),
    output: out,
    depend_files: rcw_common,
    build_by_default: true,
    command: [
      qoriq_rcw, '-w',
      '-i', '@INPUT@',
      '-o', '@OUTPUT@',
      '-I', rcw_local_errata_dir,
      '-I', rcw_data_dir,
      '-I', rcw_errata_dir,
    ],
  )
  rcw_bins += bin

  # Gate the size: 4092 bytes boots, 4096 does not.
  test(
    v['name'] + '-pbl-size',
    size_check,
    args: [bin],
    suite: 'size',
  )
endforeach

alias_target('rcws', rcw_bins)

# Report whether each shadowed erratum still differs from upstream. Once a
# line says "upstream matches", that copy is redundant and can be deleted.
shadow_status = []
foreach f : rcw_shadow_errata
  upstream = rcw_errata_dir / f
  if not fs.exists(upstream)
    shadow_status += f + ': local only'
  elif run_command('cmp', '-s', rcw_local_errata_dir / f, upstream,
                   check: false).returncode() == 0
    shadow_status += f + ': upstream matches, shadow can be deleted'
  else
    shadow_status += f + ': local copy wins'
  endif
endforeach

summary({
  'qoriq-rcw': qoriq_rcw.full_path(),
  'SoC .rcwi': rcw_data_dir,
  'local errata': rcw_local_errata_dir,
  'NXP errata': rcw_errata_dir,
  'errata shadow': shadow_status,
  'variants': ', '.join(variant_names),
}, section: 'nbxv3-rcw')
