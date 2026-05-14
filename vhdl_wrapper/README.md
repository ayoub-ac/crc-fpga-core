# VHDL wrapper

`crc_top_vhdl.vhd` is a thin VHDL-2008 entity that instantiates the
SystemVerilog `crc_top` core as a black-box component. Mixed-language
simulation and synthesis is supported by Vivado xsim, ModelSim, Questa,
and Riviera-PRO out of the box; the open-source GHDL+Verilator co-sim
(see `make vhdl-test`) checks only that the wrapper compiles.

## Use from a VHDL design

```vhdl
u_crc : entity work.crc_top_vhdl
  generic map (
    WIDTH         => 32,
    POLY          => x"04C11DB7",
    INIT          => x"FFFFFFFF",
    REFIN         => '1',
    REFOUT        => '1',
    XOROUT        => x"FFFFFFFF",
    WORD_PARALLEL => '0'
  )
  port map (
    clk_i        => clk,
    rst_ni       => rst_n,
    init_i       => init,
    byte_valid_i => bv,
    byte_i       => bd,
    byte_last_i  => bl,
    byte_ready_o => br,
    finalize_i   => '0',
    crc_valid_o  => crc_v,
    crc_o        => crc_w,
    byte_count_o => bcnt,
    -- word-mode ports tied off
    word_valid_i      => '0',
    word_i            => (others => '0'),
    word_byte_count_i => (others => '0'),
    word_last_i       => '0',
    word_ready_o      => open,
    init_ready_o      => open
  );
```

Add both `rtl/crc_core.sv` and `rtl/crc_top.sv` to the same compilation
library as the VHDL wrapper. Vivado / Quartus / Diamond / Radiant pick
up the SystemVerilog files automatically when configured for
mixed-language projects.
