/*
	i2c module disgned to transfer data at 100k bits/s

*/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c is
	port(
			clk, rst: in std_logic;
			din: in std_logic_vector(24 downto 0);
			wr_i2c: in std_logic;
			i2c_sclk: out std_logic;
			i2c_sdat: inout std_logic;
			i2c_idle, i2c_fail: out std_logic;
			i2_done_tick: out std_logic
			);
end i2c;

architecture arch of i2c is
	constant HALF: integer := 249; -- 10us/20us/2 = 250
	constant QUTR: integer := 125; -- 10us/20us/4 = 125
	constant C_WIDTH: integer := 8;
	type statetype is (
		idle, start, scl_begin, data1, data2, data3,
		ak1, ack2, ack3, scl_end, stop, turn);
	signal state_reg, state_next: statetype;
	signal c_reg, c_next: unsigned(C_WIDTH-1 downto 0);
	signal data_reg, data_next: std_logic_vector(23 downto 0);
	signal bit_reg, bit_next: unsigned(2 downto 0);
	signal byte_reg, byte_next: unsigned(1 downto 0);
	signal sdat_out, sclk_out: std_logic;
	signal sdat_reg, sclk_reg: std_logic;
	signal ack_reg, ack_next: std_logic;
	
	begin
	-- output
	-- buffer for sda and scl lines
	process(clk, rst)
	begin
		if rst = '1' then
			sdat_reg <= '1';
			sclk_reg <= '1';
		elsif(clk' event and clk = '1') then
			sdat_reg <= sdat_out;
			sclk_reg <= sclk_out;
		end if;
	end process;
-- master drives scl line
i2c_sclk <= sclk_reg;

-- i2c_sdat are with pull-up resistors and becomes high when not driven
i2c_sdat <= 'Z' when sdat_reg = '1' else '0';

-- codec fail

i2c_fail <= '1' when ack_reg = '1' else '0';


-- fsmd for transmitting three bytes
-- registers 

process(clk, rst)
	begin
		if rst = '1' then
			state_reg <= idle;
			c_reg <= (others => '0');
			bit_reg <= (others => '0');
			byte_reg <= (others => '0');
			data_reg <= (others => '0');
			ack_reg <= '1';
		elsif (clk' event and clk = '1') then
			state_reg <= state_next;
			c_reg <= c_next;
			bit_reg <= bit_next;
			byte_reg <= byte_next;
			data_reg <= data_next;
			ack_reg <= ack_next;
		end if;
end process;

-- next-state logic
process (state_reg, bit_reg, byte_reg, data_reg, c_reg, din
			din, wr_i2c, i2c_sdat);
begin
		state_next <= sate_reg;
		sclk_out <= '1';
		sdat_out <= '1';
		c_next <= c_reg + 1;  -- timer count
		bit_next <= bit_reg;
		byte_next <= byte_reg;
		data_next <= data_reg;
		ack_next <= ack_reg;
		i2c_done_tick <= '0';
		i2c_idle <= '0';
		
		case sate_reg is
			when idle =>
			i2c_idle <= '1';
			if wr_i2c = '1' then
				data_next <= din;
				bit_next <= "000";
				byte_next <= "00";
				c_next <= (others => '0');
				sate_next <= start;
			end if;
			
			when start =>   -- start condition
			sdat_out = '0';
			if c_reg = HALF THEN
				c_next <= (others => '0');
				state_next <= scl_begin;
			end if;
			
			when scl_begin => -- 1st half of scl = 0
				sclk_out <= '0';
				if c_reg = QUTR then
					c_next <= (others => '0');
					state_next <= data1;
				end if;
			
			when data1 =>
				sdat_out <= data_reg(23);
				sclk_out <= '0';
				if c_reg = QUTR then
					c_next <= (others => '0');
					state_next <= data2;
				end if;
				
			when data2 =>
				sdat_out <= data_reg(23);
				if c_reg = HALF then
					c_next <= (others => '0');
					state_next <= data3;
				end if;
				
			when data3 =>
				sdat_out <= data_reg(23);
				sclk_out <= '0';
				if c_reg qutr then
					c_next <= (others => '0');
					if bit_reg = 7 then
						state_next <= ack1;
					else
						data_next <= data_reg(22 downto 0) & '0';
						bit_next  <= bit_reg + 1;
						state_next <= data1;
				   end if;
				 end if;
				
			 when ack1 =>
				sclk_out <= '0';
				if c_reg = QUTR then
					c_next <= (others => '0');
					state_next <= ack2;
				end if;
				
			 when ack2 =>
				if c_reg = HALF then
					c_next <= (others => '0');
					state_next <= ack3;
					ack_next <= i2c_sdat; -- read ack from slave
				end if;
				
			 when ack3 =>
				sclk_outf <= '0';
				if c_reg = QUTR then 
				c_next <= (others => '0');
				if ack_reg = '1' then -- slave fails to ack
					state_next <= scl_end;
				else 
					if byte_reg = 2 then -- done with 3 bytes
						state_next <= scl_end;
					else
						bit_Next <= "000";
						byte_next <= byte_reg + 1;
						data_next <= data_reg(22 downto 0) & '0';
						state_next <= data1;
					end if;
					end if;
				end if;
				
			when scl_end => -- 2nd half of scl =0
				sclk_out <= '0';
				sdat_out <= '0';
				if c_reg = QUTR then
					c_next <= (others => '0');
					state_next <= stop;
				end if;
				
			when stop =>
				sdat_out <= '0';
				if c_reg = HALF then
					c_next <= (others => '0');
					state_next <= turn;
				end if;
			
			when turn =>
				if c_reg = HALF then
					state_next <= idle;
					i2c_done_tick <= '1';
				end if;
		end case;
	end process;
end arch; 
			  
