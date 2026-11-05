# Validation

The original RTL is preserved as supplied. `make lint` elaborates the design with Verilator; `-Wno-fatal` retains compiler warnings in the output.

Observed warning classes: LATCH, WIDTHEXPAND, WIDTHTRUNC.

`npm test` checks the accompanying architectural reference models against independent numerical or sequential references. These tests validate model behavior; RTL simulation and synthesis are separate flows.

## RTL workload runs

Verilator 5.052 passed all ten workload names listed in the README, including both full 224-element quicksort images, both convolution images, multiply, and the hazard and compression benches. These runs used the submitted CHIP.v and the portable functional slow-memory model. Timing-annotated simulation and physical signoff were not rerun. The tests do not establish a measured maximum operating frequency.
