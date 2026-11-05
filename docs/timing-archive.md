# Timing annotation archive

These SDFs were exported alongside the submitted design netlists. Each file annotates a specific design hierarchy and includes instance paths, interconnect delays, cell arcs, and timing checks. The synthesis and post-route results must be paired with their corresponding netlists. The submitted exports were copied byte for byte.

| Stage | File | CELL records | SHA-256 |
|---|---|---:|---|
| synthesis | [CHIP_syn.sdf](../implementation/synthesis/CHIP_syn.sdf) | 43,575 | `cc66cf6f208f127f2f14c49f28c426b16e8faa5ae0052c7a247361025de5224f` |

The RTL regressions exercise the source design with functional timing. To perform a separate gate-level timing run, load the matching mapped netlist and the authorized simulation cell models in a licensed simulator, annotate the file on that design instance, and inspect the simulator’s annotation coverage and timing violations. Gate-level SDF simulation has not been run as part of this repository validation.
