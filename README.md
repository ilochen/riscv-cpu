# RISC-V CPU and Caches

A five-stage RISC-V processor with forwarding, hazard interlocks, compressed-instruction assembly, multicycle multiplication, and separate instruction/data caches. The front end uses a 16-line direct-mapped I-cache; the D-cache has 16 sets and two ways. The multiplier uses hold/capture control so ordinary instructions retain the base pipeline clock.

[Interactive architecture and design decisions](https://ilochen.github.io/projects/riscv-cpu/)

## Source layout

- `rtl/CHIP.v`: integrated CPU/cache RTL, top module `CHIP`.
- `workloads/quicksort/`: instruction/data images, expected output, original generator, and testbed component.
- `assets/cpu-hardware.js`: architectural pipeline, cache, and sequential reference models.
- `assets/cpu-quicksort.js`: executable image data used by the portfolio's sorting visualization.
- `tests/cpu-hardware.test.js`: forwarding, stalls, flushes, compressed instruction addressing, and quicksort result checks.

## Run

```sh
make lint          # Verilator source elaboration
npm test           # Node.js 22+, no dependencies
```

`CHIP` exposes separate 128-bit slow-memory interfaces for instruction and data traffic. The workload folder's original Readme describes image layout. Its TestBed module is a workload checker intended for a system-level memory/testbench harness.

The active multiply expression is synthesized through Synopsys; the explicit Wallace-tree implementation is retained in the RTL as a design variant. Multicycle hold control governs availability and capture of the product. Cache and multiplier alternatives were evaluated using the area × execution-time² objective.

See [validation notes](docs/validation.md) for the checked artifacts and compiler diagnostics.

## Run the processor RTL

With Verilator 5, a C++20 compiler, and Make, run:

```sh
make rtl-test                           # uncompressed quicksort on 224 signed integers
make rtl-test WORKLOAD=QSort            # compressed quicksort image
make rtl-test WORKLOAD=Mul              # multiply extension
```

The system harness connects CHIP to separate 128-bit instruction and data memories, loads the instruction and data images, and compares the resulting stores against the workload checker. The included Verilator memory model uses a three-edge response and two-edge turnaround for functional verification. The original course memory model is in `sim/course_slow_memory.v` for legacy event-driven simulators. Simulate exactly one memory model at a time.

| Workload | How to select it |
|---|---|
| Baseline pipeline / forwarding | `noHazard`, `hasHazard` |
| Branch prediction stress | `BrPred` |
| Compressed instruction pair | `compression`, `compression_uncompressed` |
| Multicycle multiply | `Mul` |
| Sorting | `QSort`, `QSort_uncompressed` |
| Convolution kernel | `Conv`, `Conv_uncompressed` |

For quicksort the checker compares the 256-word data image, which includes the sorted subrange at words 32–255. Stack traffic occurs outside the checked range. The ported bench explicitly bounds its comparison-memory write index so that out-of-range stack writes cannot wrap into the checker array in a two-state simulator. The test returns a failure status on any mismatch or timeout.

The quicksort generator uses `data.npy`, NumPy, and both instruction images. Its relative paths assume the current directory is a writable copy of `workloads/quicksort/`. The convolution and extension generators include their assembly or reference inputs wherever supplied.

## Implementation archive

[Mapped synthesis Verilog](implementation/synthesis/CHIP_syn.v) contains the submitted design connectivity; simulating it requires separately supplied authorized cell models. [Course baseline constraints](implementation/synthesis/course_baseline.sdc) give the starter 10 ns clock and I/O assumptions. This file documents the starter, and does not establish the timing target or multicycle path exceptions of the final synthesized run.

The [timing archive](docs/timing-archive.md) identifies the paired design-specific SDF exports, their hashes, and the requirements for a separate gate-level run.
