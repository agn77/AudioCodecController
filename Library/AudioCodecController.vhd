/*
	Audio Codec Controller: converts analog signals into digital data
	and converts the data back to analog signals. Contains an ADC and a DAC
	from the WM8731 on board the fpga. 
	
	This project was made using the textbook, "Embedded SoPC design with Nios II
	Processor and VHDL Examples", by Pong P. Chu.


*/


Library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity AudioCodecController is 
	generic(FIFO_SIZE: integer:=3);
	port(clk, rst: in std_logic;
			--WM8731
			m_clk, b_clk, dac_lr_clk, adc_lr_clk: out std_logic;
			dacdat: out std_logic;
			adcdat: in std_logic;
			i2c_sclk: out std_logic;
			i2c_sdat: inout std_logic;
			--main system
			wr_i2c: in std_logic;
			i2c_packet: in std_logic_vector(23 downto 0);
			i2c_idle: out std_logic;
			rd_adc_fifo: in std_logic;
			adc_fifo_out: out std_logic_vector(23 downto 0);
			adc_fifo_empty: out std_logic;
			wr_dac_fifo: in std_logic;
			dac_fifo_in: in std_logic_vector(23 downto 0);
			dac_fifo_full: out std_logic;
			sample_tick: out std_logic
			);
end AudioCodecController;

architecture arch of AudioCodecController is
signal dac_data_in: std_logic_vector(31 downto 0);
signal adc_data_out: std_logic_vector(31 downto 0);
signal dac_done_tick: std_logic;
begin
sample_tick <= dac_done_tick;
-- instantiating i2c module
i2c_unit: entity work.i2c(arch)
	port map(clk => clk,
				rst => rst,
				wr_i2c => wr_i2c,
				din => i2c_packet,
				i2c_sclk => i2c_sclk,
				i2c_sdat => i2c_sdat,
				i2c_idle => i2c_idle,
				i2c_open_tick => open,
				i2c_fail => open);

-- dac/adc codec
dac_adc_unit: entity work.adc_dac(arch)
	port map(clk => clk,
				rst => rst,
				dac_data_in => dac_data_in,
				adc_data_out => adc_data_out,
				m_clk => m_clk,
				b_clk => b_clk, 
				dac_lr_clk => dac_lr_clk,
				adc_lr_clk => adc_lr_clk,
				dacdat => dacdat,
				adcdat => adcdat,
				load_done_tick => dac_done_tick);

-- adc fifo module 
fifo_adc_unit: entity work.fifo(arch)
	generic(B => 32, W => FIFO_SIZE)
	port map(clk => clk,
				rst => rst,
				rd => rd_adc_fifo,
				wr => dac_done_tick,
				w_data => adc_data_out,
				empty => dac_fifo_empty,
				full => open,
				r_data => adc_fifo_out);
				
-- dac fifo 
fifo_dac_unit: entity work.fifo(arch)
	generic(B => 32, W => FIFO_SIZE)
	port map( clk => clk,
				rst => rst,
				rd => dac_done_tick,
				wr => wr_dac_fifo,
				w_dat => dac_fifo_in,
				empty => open,
				full => dac_fifo_full,
				r_data => dac_data_in);
				
end arch;

