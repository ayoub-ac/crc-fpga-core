-- SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
--
-- VHDL-2008 entity wrapping crc_top for VHDL-only design hierarchies.
-- The architecture is a black-box component; the SystemVerilog core lives
-- in rtl/crc_top.sv and must be added to the same compilation library.
-- Mixed-language elaboration is supported by Vivado xsim, ModelSim,
-- Questa, and Riviera-PRO out of the box.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc_top_vhdl is
  generic (
    WIDTH         : integer                       := 32;
    POLY          : std_logic_vector(31 downto 0) := x"04C11DB7";
    INIT          : std_logic_vector(31 downto 0) := x"FFFFFFFF";
    REFIN         : std_logic                     := '1';
    REFOUT        : std_logic                     := '1';
    XOROUT        : std_logic_vector(31 downto 0) := x"FFFFFFFF";
    WORD_PARALLEL : std_logic                     := '0'
  );
  port (
    clk_i             : in  std_logic;
    rst_ni            : in  std_logic;

    init_i            : in  std_logic;
    init_ready_o      : out std_logic;

    byte_valid_i      : in  std_logic;
    byte_i            : in  std_logic_vector(7 downto 0);
    byte_last_i       : in  std_logic;
    byte_ready_o      : out std_logic;

    word_valid_i      : in  std_logic;
    word_i            : in  std_logic_vector(31 downto 0);
    word_byte_count_i : in  std_logic_vector(2 downto 0);
    word_last_i       : in  std_logic;
    word_ready_o      : out std_logic;

    finalize_i        : in  std_logic;

    crc_valid_o       : out std_logic;
    crc_o             : out std_logic_vector(WIDTH-1 downto 0);
    byte_count_o      : out std_logic_vector(31 downto 0)
  );
end entity crc_top_vhdl;

architecture rtl of crc_top_vhdl is

  component crc_top is
    generic (
      WIDTH         : integer;
      POLY          : std_logic_vector(31 downto 0);
      INIT          : std_logic_vector(31 downto 0);
      REFIN         : std_logic;
      REFOUT        : std_logic;
      XOROUT        : std_logic_vector(31 downto 0);
      WORD_PARALLEL : std_logic
    );
    port (
      clk_i             : in  std_logic;
      rst_ni            : in  std_logic;
      init_i            : in  std_logic;
      init_ready_o      : out std_logic;
      byte_valid_i      : in  std_logic;
      byte_i            : in  std_logic_vector(7 downto 0);
      byte_last_i       : in  std_logic;
      byte_ready_o      : out std_logic;
      word_valid_i      : in  std_logic;
      word_i            : in  std_logic_vector(31 downto 0);
      word_byte_count_i : in  std_logic_vector(2 downto 0);
      word_last_i       : in  std_logic;
      word_ready_o      : out std_logic;
      finalize_i        : in  std_logic;
      crc_valid_o       : out std_logic;
      crc_o             : out std_logic_vector(WIDTH-1 downto 0);
      byte_count_o      : out std_logic_vector(31 downto 0)
    );
  end component;

begin

  u_crc : crc_top
    generic map (
      WIDTH         => WIDTH,
      POLY          => POLY,
      INIT          => INIT,
      REFIN         => REFIN,
      REFOUT        => REFOUT,
      XOROUT        => XOROUT,
      WORD_PARALLEL => WORD_PARALLEL
    )
    port map (
      clk_i             => clk_i,
      rst_ni            => rst_ni,
      init_i            => init_i,
      init_ready_o      => init_ready_o,
      byte_valid_i      => byte_valid_i,
      byte_i            => byte_i,
      byte_last_i       => byte_last_i,
      byte_ready_o      => byte_ready_o,
      word_valid_i      => word_valid_i,
      word_i            => word_i,
      word_byte_count_i => word_byte_count_i,
      word_last_i       => word_last_i,
      word_ready_o      => word_ready_o,
      finalize_i        => finalize_i,
      crc_valid_o       => crc_valid_o,
      crc_o             => crc_o,
      byte_count_o      => byte_count_o
    );

end architecture rtl;
