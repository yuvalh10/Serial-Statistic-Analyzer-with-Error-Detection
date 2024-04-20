-- Library and packages used for standard logic operations
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Entity declaration for the serial to parallel module
entity main_controller is
    generic (
            G_DATA_BITS : integer := 8; -- Generic for data width
            G_RESET_ACTIVE_VALUE : std_logic := '0' -- Generic for reset active value
    );
    port (
        CLK             : in std_logic; -- Clock input
        RST             : in std_logic; -- Reset input
        START           : in std_logic; -- Start signal
        DISPLAY         : in std_logic; -- Display signal
        DIN             : in std_logic_vector(G_DATA_BITS-1 downto 0); -- Input data
        DIN_VALID       : in std_logic; -- Input data valid signal
        PARITY_ERROR    : in std_logic; -- Parity error signal
        DATA_REQUEST    : out std_logic; -- Data request signal
        RESULT          : out std_logic_vector(G_DATA_BITS-1 downto 0); -- Output result
        RESULTS_READY   : out std_logic; -- Results ready signal
        RESULT_TYPE     : out std_logic_vector(4 downto 0) -- Result type signal
    );
end entity;

architecture behave of main_controller is
    -- Constants
    constant C_DATA_BLOCK_SIZE : integer := 64; -- Size of data block
    constant C_DATA_REQUEST_PULSE_WIDTH : integer:= 150; -- Width of data request pulse
    
    -- Array type for data storage
    type slv_array is array (integer range <>) of std_logic_vector(G_DATA_BITS-1 downto 0);
    
    -- Enumeration for main state machine states
    type main_sm_states is (
        st_idle,    -- Idle state
        st_gen_data_request,
        st_get_data, 
        st_sort_data,
        st_show_statistics
    );
    
    -- Signals declaration
    signal pre_state : main_sm_states; -- Previous state
    signal data_array : slv_array(0 to C_DATA_BLOCK_SIZE-1); -- Array to store input data
    signal data_cnt : integer range 0 to C_DATA_BLOCK_SIZE-1  := 0; -- Counter for data processing
    signal req_pulse_width_cnt : integer := 0; -- Counter for data request pulse width
    signal sort_iteration : integer := 0; -- Counter for sorting iterations
    signal parity_error_counter : integer range 0 to C_DATA_BLOCK_SIZE:= 0; -- Counter for parity errors
    signal sum : std_logic_vector(G_DATA_BITS+5 downto 0) := (others => '0'); -- Sum of input data
    signal median_sum : std_logic_vector(G_DATA_BITS downto 0) := (others => '0'); -- Sum for calculating median
    signal median : std_logic_vector(G_DATA_BITS-1 downto 0) := (others => '0'); -- Median value
    signal result_select : integer range 0 to 4 := 0; -- Selector for different results
    signal result_int : std_logic_vector (G_DATA_BITS-1 downto 0) := (others =>'0'); -- Internal result storage
    signal result_ready_int : std_logic := '0'; -- Internal signal indicating result readiness
    signal result_type_int: std_logic_vector (4 downto 0) := (others =>'0'); -- Internal signal indicating result type
    signal s_data_request : std_logic := '0'; -- Signal for data request
    
begin
    -- Main state machine process
    sm1: process (CLK,RST)
    begin
        if RST = '1' then -- Reset condition
            -- Reset all signals and variables
            data_array <= (others => (others => '0'));
            pre_state <= st_idle;
            data_cnt <= 0;
            sort_iteration <= 0;
            sum <= (others => '0');
            result_select <= 0;
            parity_error_counter <= 0;
            result_ready_int <= '0';
            s_data_request <= '0';
            median <= (others => '0');
            median_sum <= (others => '0');
            result_type_int <= (others => '0');
            RESULT <= (others => '0');
            req_pulse_width_cnt <= C_DATA_REQUEST_PULSE_WIDTH;
        elsif rising_edge(clk) then -- Clock rising edge
            case pre_state is 
                when st_idle => -- Idle state
                    result_type_int <= (others => '0');
                    if START = '1' then -- Check for start signal
                        pre_state <= st_gen_data_request;
                        parity_error_counter <= 0;
                        median_sum <= (others => '0');                            
                        result_ready_int <= '0';
                        sum <= (others => '0');
                        data_cnt <= 0;
                        median <= (others => '0');
                        req_pulse_width_cnt <= C_DATA_REQUEST_PULSE_WIDTH;
                        result_type_int <= (others => '0');
                        sort_iteration <= 0;
                    end if;
                
                when st_gen_data_request => -- Generate data request
                    pre_state <= st_get_data;
                
                when st_get_data => -- Get input data
                    if req_pulse_width_cnt > 0 then
                        s_data_request <= '1';
                        req_pulse_width_cnt <= req_pulse_width_cnt -1;
                    else
                        s_data_request <= '0';
                    end if;
                    
                    if DIN_VALID = '1' then
                        data_array(data_cnt) <= DIN;
                        if data_cnt = C_DATA_BLOCK_SIZE-1 then
                            pre_state <= st_sort_data;
                        else
                            data_cnt <= data_cnt + 1;
                        end if;
                        sum <= sum + ("000000" & DIN); -- Add data to sum
                        if PARITY_ERROR = '1' then
                            parity_error_counter <= parity_error_counter + 1;
                        end if;
                    end if;
                
                when st_sort_data => -- Sort data
                    if data_cnt = sort_iteration then
                        if sort_iteration = C_DATA_BLOCK_SIZE-1 then
                            pre_state <= st_show_statistics;
                            result_ready_int <= '1';
                        else
                            sort_iteration <= sort_iteration + 1;
                        end if;
                        data_cnt <= C_DATA_BLOCK_SIZE-1;
                    else -- bubble sort
                        if data_array(data_cnt) > data_array(data_cnt-1) then
                            data_array(data_cnt) <= data_array(data_cnt-1);
                            data_array(data_cnt-1) <= data_array(data_cnt);
                        end if;
                        data_cnt <= data_cnt - 1;
                    end if;
                
                when st_show_statistics => -- Show statistics
                    median_sum <= ('0' & data_array(C_DATA_BLOCK_SIZE/2)) + ('0' & data_array((C_DATA_BLOCK_SIZE-1)/2));
                    median <= median_sum(median_sum'high downto 1); -- Calculate median
                    if DISPLAY = '1' then -- Check for display signal
                        if result_select = 4 then
                            result_select <= 0; 
                        else 
                            result_select <= result_select + 1;
                        end if;
                    end if;
                    if START = '1' then -- Check for START signal
						pre_state <= st_idle; -- Return to idle state
						result_ready_int <= '0';
						result_select <= 0;
					end if;
					if result_ready_int = '1' then -- Check if result is ready
                    -- Select result based on result_select
						if result_select = 0 then
							result_type_int <= "00001"; -- Result type for maximum data element
							RESULT <= data_array(0); -- Output maximum data element
						elsif result_select = 1 then
							result_type_int <= "00010"; -- Result type for minimum data element
							RESULT <= data_array(C_DATA_BLOCK_SIZE-1); -- Output minimum data element
						elsif result_select = 2 then
							result_type_int <= "00100"; -- Result type for average
							RESULT <= sum(G_DATA_BITS+5 downto 6); -- Output average
						elsif result_select = 3 then
							result_type_int <= "01000"; -- Result type for median
							RESULT <= median; -- Output median
						elsif result_select = 4 then
							result_type_int <= "10000"; -- Result type for parity error counter
							RESULT <= std_logic_vector(to_unsigned(parity_error_counter, RESULT'length)); -- Output parity error counter
						end if;
					end if;
				end case;
			end if;
	end process;

	-- Assign outputs
	RESULTS_READY <= result_ready_int; -- Output results ready signal
	RESULT_TYPE <= result_type_int; -- Output result type
	DATA_REQUEST <= s_data_request; -- Output data request signal

end behave;