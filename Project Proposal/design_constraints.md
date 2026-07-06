For now , we are planning our Design Constraints to be :

### Configurable Architecture
- Parameterized systolic array size (e.g., 2×2, 4×4, 8×8)

### Specifications
- It will take 16 bit Floating Point input
- It will give 32 bit Fixed Point Output after accumulation

### Compute Architecture
- Pipelined MAC-based Processing Elements
- Efficient data reuse through systolic dataflow
- High-throughput parallel computation

### Memory System
- SRAM-based input/output buffering
- Streaming data movement
- Optional double buffering support

### Verification Strategy
- SystemVerilog-based testbenches
- Directed and random test cases
- Functional correctness validation

### ASIC-Oriented Design Flow
- RTL design and synthesis
- Static timing analysis
- Floorplanning and placement
- Clock tree synthesis
- Power and area estimation
- DRC/LVS compliance

### FPGA Validation
- Hardware prototyping on FPGA
- Functional benchmarking and validation

### RISC-V Core Integration
- Its an extension
- If time permits , we will integrate a lightweight RISC-V Core with our IP