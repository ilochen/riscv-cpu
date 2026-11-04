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
