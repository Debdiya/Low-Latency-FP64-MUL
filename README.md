
This project presents a highly optimized IEEE-754 Double-Precision (FP64) Multiplier implemented in Verilog. Unlike standard IP cores that rely heavily on generic DSP mapping, this implementation utilizes a Hybrid Mantissa Multiplication strategy combining the 2-partition Karatsuba algorithm with Vedic mathematics.

The result is a lightning-fast datapath achieving 2.065 ns delay while maintaining a lean footprint of only 425 LUTs, making it ideal for high-frequency FPGA-based scientific computing and RTL accelerators.
