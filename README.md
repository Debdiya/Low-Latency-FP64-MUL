
This project presents a highly optimized IEEE-754 Double-Precision (FP64) Multiplier implemented in Verilog. Unlike standard IP cores that rely heavily on generic DSP mapping, this implementation utilizes a Hybrid Mantissa Multiplication strategy combining the 2-partition Karatsuba algorithm with Vedic mathematics.

The result is a lightning-fast datapath achieving 2.065 ns delay while maintaining a lean footprint of only 425 LUTs, making it ideal for high-frequency FPGA-based scientific computing and RTL accelerators.


The core efficiency stems from the fp64_mantissa_mul_hybrid_pipe3 module, which breaks down the massive 53x53-bit mantissa multiplication into manageable, high-speed parallel paths:

Upper Partition (27x27 bits): Mapped efficiently to high-speed FPGA DSP Slices.

Lower Partition (26x26 bits): Decomposed into four 13x13 Vedic Multipliers, significantly reducing the logic depth compared to traditional Wallace trees.

Hybrid Reconstruction: A 2-partition Karatsuba approach is used to merge the partial products, minimizing the number of required additions.

Achieved a 2.065 ns datapath delay and 425 LUT footprint, outperforming standard IP cores by ~41% in speed and ~29% in area efficiency.
