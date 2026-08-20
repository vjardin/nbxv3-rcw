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

## Intends: ship the RCWs inside the system's FIT

The build framework (Buildroot, etc.) should archive
every variant of RCW/PBL that are built here into the as
`rcw-<carrier>`, alongside any other kernel's `fdt-`, MC's `dpc-` or `dpl-`:

| FIT image        | source                                   | size |
|------------------|------------------------------------------|------|
| `rcw-nbv30`      | `rcw_nbxv30x31_2200_700_2400_13_7_3.bin` | 2632 |
| `rcw-nbv32`      | `rcw_nbxv32_2200_700_2400_13_7_3.bin`    | 2816 |
| `rcw-standalone` | `rcw_nbxv3_withoutIOs_nor.bin`           |  280 |

At worst, the size will be 4K each, so it is marginal enough.

The intent is recovery from a wrongly flashed RCW: the CPU module.
So a module can boot an any RCW that does not match the
carrier it is plugged into. A running U-Boot can probe the respective carriers
and, on a mismatch, rewrite NOR sector 0 from the FIT and reset to run
on the proper expected RCW/PBL.

That is safe because the whole PBL=RCW+PBI always fits in the first 4 KiB
erase sector and the ATF's BL2 lives beyond.

### Examples with a Nbxv32

```
=> imxtract ${kernel_addr_r} rcw-nbv32 0xa8000000
## Copying 'rcw-nbv32' subimage from FIT image at c0000000 ...
   sha256+    Loading part 0 ... OK
=> sf read 0xa9000000 0 0x1000
=> cmp.b 0xa8000000 0xa9000000 0xb00
Total of 2816 byte(s) were the same          <- FIT copy == live NOR sector 0

=> imxtract ${kernel_addr_r} rcw-nbv30 0xab000000
=> cmp.b 0xab000000 0xa9000000 0xa48
byte at 0xab00002a (0xf0) != byte at 0xa900002a (0xd0)
Total of 42 byte(s) were the same            <- wrong carrier diverges at 0x2a
```

TBC: do we need the exact size ?

### Sketch of the reflash path

```sh
sf probe 3:0
sf read ${kernel_addr_r} ${fit_nor_offset} ${fit_nor_size}
imxtract ${kernel_addr_r} rcw-${detected} <scratch>   # sha256-checked
sf read <scratch2> 0 0x1000
cmp.b <scratch> <scratch2> <size>                     # mismatch?
  -> sf erase 0 0x1000 && sf write <scratch> 0 <size> && reset
```
