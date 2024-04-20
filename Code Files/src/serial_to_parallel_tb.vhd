library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity serial_to_parallel_tb is
end entity;

architecture behave of serial_to_parallel_tb is
    constant CLK_PERIOD          : time := 40 ns;                 -- Clock period
    constant C_RESET_ACTIVE_VALUE: std_logic := '0';             -- Reset active value
    constant C_DATA_BITS_W_PARITY: integer := 9;                 -- Data bits with parity

    component serial_to_parallel
        generic (
            G_DATA_BITS_W_PARITY : integer := 9;                -- Data bits with parity
            G_LSB_FIRST          : boolean := true;            -- LSB first
            G_PARITY             : std_logic := '0';            -- Parity type (0: even, 1: odd)
            G_RESET_ACTIVE_VALUE : std_logic := '0'             -- Reset active value
        );
        port (
            CLK            : in std_logic;                      -- Clock input
            RST            : in std_logic;                      -- Reset input
            SER_DIN        : in std_logic;                      -- Serial Data Input
            SER_DIN_VALID  : in std_logic;                      -- Valid signal for serial input
            PAR_DOUT       : out std_logic_vector (G_DATA_BITS_W_PARITY-2 downto 0); -- Parallel Data Output
            PAR_DOUT_VALID : out std_logic;                      -- Valid signal for parallel output
            PARITY_ERROR   : out std_logic                      -- Output indicating parity error
        );
    end component;

    signal run               : std_logic := '1';                  -- Signal to control simulation running
    signal s_clk             : std_logic := '0';                  -- Clock signal
    signal s_rst             : std_logic := '0';                  -- Reset signal
    signal s_ser_din         : std_logic := '0';                  -- Serial data input signal
    signal s_ser_din_valid   : std_logic := '0';                  -- Valid signal for serial input
    signal s_par_dout        : std_logic_vector (C_DATA_BITS_W_PARITY-2 downto 0) := (others => '0'); -- Parallel data output signal
    signal s_par_dout_valid  : std_logic := '0';                  -- Valid signal for parallel output
    signal s_parity_error    : std_logic := '0';                  -- Parity error signal

begin
    -- Instantiate DUT
    DUT : serial_to_parallel
        generic map (G_RESET_ACTIVE_VALUE => C_RESET_ACTIVE_VALUE)
        port map (
            CLK            => s_clk,
            RST            => s_rst,
            SER_DIN        => s_SER_DIN,
            SER_DIN_VALID  => s_ser_din_valid,
            PAR_DOUT       => s_par_dout,
            PAR_DOUT_VALID => s_par_dout_valid,
            PARITY_ERROR   => s_parity_error
        );
                
    -- Generate clock signal with a period of CLK_PERIOD
    run <= '1', '0' after 2000 ns;
    clk_create: process
    begin
        while run = '1' loop
            s_clk <= '1','0' after CLK_PERIOD/2;
            wait for CLK_PERIOD;
        end loop;
        s_clk <= '1';
        wait;
    end process;

    -- Reset generation
    s_rst <= '1', '0' after 20 ns;

    -- Serial input generation
    s_ser_din        <= '0', '1' after 435 ns, '0' after 910 ns;
    s_ser_din_valid  <= '0', '1' after 100 ns, '0' after 455 ns, '1' after 535 ns, '0' after 930 ns,
                        '1' after 1090 ns, '0' after 1450 ns;
end behave;
	
	-- LSB:
	-- first 11111111-1 and expected 1 at the parity error
	-- second 00000000-0 and expected 0 at the parity error`
	
	--MSB:
	--same as LSB but the shift register is changing direction