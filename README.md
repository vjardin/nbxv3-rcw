# nbxv3-rcw — Reset Configuration Words for the Nodebox v3 CPU module

The LX2160A uses 128 bytes of RCW at power-on for its settings, then
executes the PBI commands that follow before kicking the ARM cores.

The build can use the old NXP `rcw.py` or the new
[`qoriq-rcw`](https://github.com/vjardin/qoriq-rcw).

## Building

```sh
meson setup build
meson compile -C build
meson test -C build
```

Output lands in `build/` named after the source, e.g.
`build/rcw_nbxv32_2200_700_2400_13_7_3.bin`.

### Where the includes come from

Few paths are needed:

| Option              | Default        | Supplies |
|---------------------|----------------|----------|
| `-Dqoriq-rcw-path=` | `../qoriq-rcw` | the compiler, `build/qoriq-rcw` or `PATH` |
| `-Dqoriq-rcw-data=` | `<qoriq-rcw-path>/data` | per-SoC `.rcwi` bitfield definitions |
| `-Drcw-ref-dir=`    | `../rcw`       | upstream NXP RCWs, `lx2160asi/` and its errata|

The local `lx2160asi/` directory is searched before both of those. It
holds verbatim copies of four upstream errata files that teach an
erratum to skip the blocks a board's SerDes protocol does not enable,
pending their merge into `nxp-qoriq/rcw`; see `lx2160asi/README`.

### The PBL size gate

The LX2160A Service Processor fails loading the PBI once its internal
scratch buffer is exhausted. The ceiling is undocumented in the reference
manual and was measured on silicon: 4092 bytes boots, 4096 does not.

On this module the `.bin` here is the whole PBL: TF-A's `create_pbl`
runs with `-x` (XIP from the FlexSPI AHB window) and appends neither a
Block Copy nor a `BOOTLOCPTR` write, and BL2 is `dd`'d in afterwards.

## The boot-iteration marker

`uart1_version.rcwi` emits a build marker on UART1 before any BL2 code
runs.

The same file also writes a build stamp in DCFG SCRATCHRW13, which ATF
BL2 reads back and prints as `Iliad nbxv3<c> RCW v.<date>`:

```
 31   28 27   24 23   16 15    8 7     0
+-------+-------+-------+-------+-------+
|CARRIER|  TAG  |  YY   |  MM   |  DD   |   all BCD
+-------+-------+-------+-------+-------+
```
