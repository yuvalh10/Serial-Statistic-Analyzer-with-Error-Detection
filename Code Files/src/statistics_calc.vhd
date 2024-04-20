-- Library and packages used for standard logic operations
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity statistics_calc is
    port(
        CLK            : in std_logic;
        RSTn           : in std_logic; -- Active low reset
        START          : in std_logic; -- Start signal
        DISPLAY        : in std_logic; -- Display signal
        HEX0           : out std_logic_vector(6 downto 0); -- 7-segment display output
        HEX1           : out std_logic_vector(6 downto 0); -- 7-segment display output
        HEX2           : out std_logic_vector(6 downto 0); -- 7-segment display output
        HEX3           : out std_logic_vector(6 downto 0); -- 7-segment display output
        LEDR           : out std_logic_vector(9 downto 5); -- LED output
		LEDG           : out std_logic_vector(2 downto 1) -- LED output
    );
end entity;

architecture structural of statistics_calc is
    -- Constants for configuration
    constant C_DATA_BLOCK_SIZE       : integer := 64;
    constant C_DATA_BITS             : integer := 8;
    constant C_RESET_ACTIVE_VALUE    : std_logic := '1'; -- Active low reset
    constant C_DATA_BITS_W_PARITY    : integer := 9;
    constant C_LSB_FIRST             : boolean := false;
    constant C_PARITY                : std_logic := '0';
    constant C_DERIVATE_RISING_EDGE  : boolean := false; -- Rising edge detection
    constant C_SIG_IN_INIT_VALUE     : std_logic := '0';

    -- Component declarations
    component serial_data_generator is
        generic(
            G_DATA_BLOCK_SIZE       : integer := 64;
            G_RESET_ACTIVE_VALUE    : std_logic := '0'  
        );
        port(
            CLK                     : in    std_logic;  -- System clock
            RST                     : in    std_logic;  -- Asynchronous reset (Active low)
            DATA_REQUEST            : in    std_logic;  -- Active high data request signal
            SER_DOUT                : out   std_logic;  -- Serial data output
            SER_DOUT_VALID          : out   std_logic   -- Valid signal for serial data output
        );
    end component;

	component serial_to_parallel is
		generic (
				G_DATA_BITS_W_PARITY : integer := 9;  -- Total number of bits per word including the parity bit
				G_LSB_FIRST : boolean := false;         -- TRUE for LSB first, FALSE for MSB first
				G_PARITY : std_logic := '0';           -- '0' for even parity, '1' for odd parity
				G_RESET_ACTIVE_VALUE : std_logic := '0'  -- Asynchronous reset active value
				);
		Port( 
				CLK : in STD_LOGIC;
				RST : in STD_LOGIC;
				SER_DIN : in STD_LOGIC;
				SER_DIN_VALID : in STD_LOGIC;
				PAR_DOUT : out STD_LOGIC_VECTOR(G_DATA_BITS_W_PARITY-2 downto 0);
				PAR_DOUT_VALID : out STD_LOGIC;
				PARITY_ERROR : out STD_LOGIC
			);
	end component;

	component main_controller is
		generic(
				G_DATA_BITS : integer := 8;
				G_RESET_ACTIVE_VALUE : std_logic := '0'
			   );
		port(
				CLK             : in std_logic; -- Clock input
				RST             : in std_logic; -- Reset input
				START           : in std_logic;
				DISPLAY		    : in std_logic; 
				DIN				: in std_logic_vector(G_DATA_BITS-1 downto 0);
				DIN_VALID		: in std_logic;
				PARITY_ERROR	: in std_logic;
				DATA_REQUEST	: out std_logic;
				RESULT 			: out std_logic_vector(G_DATA_BITS-1 downto 0);
				RESULTS_READY	: out std_logic;
				RESULT_TYPE		: out std_logic_vector(4 downto 0)
		);
	end component;
	
	component bcd_to_7seg is
		port(
			BCD_IN              : in    std_logic_vector(3 downto 0);
			SHUTDOWNn           : in    std_logic;
			D_OUT               : out   std_logic_vector(6 downto 0)
			);
	end component;

	component bin2bcd_12bit_sync is
		port (
			CLK         : in    STD_LOGIC;           	            -- clock input
			binIN       : in    STD_LOGIC_VECTOR (11 downto 0);     -- this is the binary number
			ones        : out   STD_LOGIC_VECTOR (3 downto 0);      -- this is the unity digit
			tenths      : out   STD_LOGIC_VECTOR (3 downto 0);      -- this is the tens digit
			hunderths   : out   STD_LOGIC_VECTOR (3 downto 0);      -- this is the hundreds digit
			thousands   : out   STD_LOGIC_VECTOR (3 downto 0)      -- this is the thousands digit
			);
	end component;
	
	component sync_diff is
		generic(
				G_DERIVATE_RISING_EDGE  : boolean := true;
				G_SIG_IN_INIT_VALUE     : std_logic := '0';
				G_RESET_ACTIVE_VALUE    : std_logic := '0'
			   );
		port(
				CLK             : in    std_logic;  -- system clock
				RST             : in    std_logic;  -- asynchronous reset, polarity is according to G_RESET_ACTIVE_VALUE
				SIG_IN          : in    std_logic;  -- async input signal
				SIG_OUT         : out   std_logic   -- synced & derivative output
			);
	end component;
	
 -- Signals declarations
    signal s_rst                : std_logic; -- Reset signal
    signal s_data_request       : std_logic; -- Data request signal
    signal s_ser_dout           : std_logic; -- Serial data output
    signal s_ser_dout_valid     : std_logic; -- Valid signal for serial data output
    signal s_par_dout           : std_logic_vector(C_DATA_BITS_W_PARITY-2 downto 0); -- Parallel data output
    signal s_par_dout_valid     : std_logic; -- Valid signal for parallel data output
    signal s_parity_error       : std_logic; -- Parity error signal
    signal s_sig_out_display    : std_logic; -- Signal for display output
    signal s_sig_out_start      : std_logic; -- Signal for start operation
    signal s_result_ready       : std_logic; -- Result ready signal
    signal s_result             : std_logic_vector(C_DATA_BITS-1 downto 0); -- Result data
    signal s_ones               : std_logic_vector(3 downto 0); -- Ones digit for BCD conversion
    signal s_tenths             : std_logic_vector(3 downto 0); -- Tenths digit for BCD conversion
    signal s_hunderths          : std_logic_vector(3 downto 0); -- Hundredths digit for BCD conversion
    signal s_thousands          : std_logic_vector(3 downto 0); -- Thousands digit for BCD conversion
    signal s_binIN              : std_logic_vector(11 downto 0); -- Binary input for BCD conversion
begin
    -- Logic for active low reset signal
    s_rst <= not(RSTn);

    -- Setting LEDs
    LEDG(1) <= '1'; -- Indicator for s_result_ready
    LEDG(2) <= s_result_ready;

    -- Setting binary input for BCD conversion
    s_binIN <= "0000" & s_result;
	
	-- Instantiate serial_data_generator component
	serial_data_generator1: serial_data_generator
		generic map(
					G_DATA_BLOCK_SIZE => C_DATA_BLOCK_SIZE,
					G_RESET_ACTIVE_VALUE => C_RESET_ACTIVE_VALUE
				   )
		port map(
				CLK => CLK,
				RST => s_rst,
				DATA_REQUEST => s_data_request,
				SER_DOUT => s_ser_dout,
				SER_DOUT_VALID => s_ser_dout_valid
				);
	
	serial_to_parallel1: serial_to_parallel
		generic map (
					G_DATA_BITS_W_PARITY => C_DATA_BITS_W_PARITY,
					G_LSB_FIRST => C_LSB_FIRST,
					G_PARITY => C_PARITY,
					G_RESET_ACTIVE_VALUE=> C_RESET_ACTIVE_VALUE
					)
		port map (
				CLK => CLK,
				RST => s_rst,
				SER_DIN => s_ser_dout,
				SER_DIN_VALID => s_ser_dout_valid,
				PAR_DOUT => s_par_dout,
				PAR_DOUT_VALID => s_par_dout_valid,
				PARITY_ERROR => s_parity_error
				);
				
	
	display_sync: sync_diff
		generic map (
					G_DERIVATE_RISING_EDGE => C_DERIVATE_RISING_EDGE,
					G_SIG_IN_INIT_VALUE => C_SIG_IN_INIT_VALUE,
					G_RESET_ACTIVE_VALUE => C_RESET_ACTIVE_VALUE
				   )
		port map (
				CLK => CLK,
				RST => s_rst,
				SIG_IN => DISPLAY,
				SIG_OUT => s_sig_out_display
				);
				
	start_sync: sync_diff
		generic map(
					G_DERIVATE_RISING_EDGE => C_DERIVATE_RISING_EDGE,
					G_SIG_IN_INIT_VALUE => C_SIG_IN_INIT_VALUE,
					G_RESET_ACTIVE_VALUE => '1'
				   )
		port map(
				CLK => CLK,
				RST => s_rst,
				SIG_IN => START,
				SIG_OUT => s_sig_out_start
				);
	
	-- Instantiate main_controller component
	main_controller1: main_controller
		generic map(
					G_DATA_BITS => C_DATA_BITS,
					G_RESET_ACTIVE_VALUE => '1' -- maybe '0' with C_RESET_ACTIVE_VALUE
					)
		port map(
				CLK => CLK,
				RST => s_rst,
				START => s_sig_out_start,
				PARITY_ERROR => s_parity_error,
				DIN_VALID => s_par_dout_valid,
				DIN => s_par_dout,
				DISPLAY => s_sig_out_display,
				DATA_REQUEST => s_data_request,
				RESULTS_READY => s_result_ready,
				RESULT => s_result,
				RESULT_TYPE => LEDR
				);

	bin2bcd: bin2bcd_12bit_sync
		port map(
				CLK => CLK,
				binIN => s_binIN,
				ones => s_ones,
				tenths => s_tenths,
				hunderths => s_hunderths,
				thousands => s_thousands
				);
				
	-- Instantiate BCD to 7-segment display components
	bcd_to_7seg1: bcd_to_7seg
		port map(
				BCD_IN => s_ones,
				SHUTDOWNn => s_result_ready,
				D_OUT => HEX0
				);
				
	bcd_to_7seg2: bcd_to_7seg
		port map(
				BCD_IN => s_tenths,
				SHUTDOWNn => s_result_ready,
				D_OUT => HEX1
				);
	
	bcd_to_7seg3: bcd_to_7seg
		port map(
				BCD_IN => s_hunderths,
				SHUTDOWNn => s_result_ready,
				D_OUT => HEX2
				);
	
	-- Turning off HEX3 output to all segments on
	HEX3 <= "1111111";
end structural;