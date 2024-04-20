-- Library and packages used for standard logic operations
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- Entity declaration for the serial to parallel module
entity serial_to_parallel is
    generic (
            G_DATA_BITS_W_PARITY : integer := 9; -- Number of data bits including parity
            G_LSB_FIRST          : boolean := false; -- True => LSB first, False => MSB first
            G_PARITY             : std_logic := '0'; -- 0 => even , 1 => odd 
            G_RESET_ACTIVE_VALUE : std_logic := '0' -- Active value for reset
    );
    port (
        CLK             : in std_logic; -- Clock input
        RST             : in std_logic; -- Reset input
        SER_DIN         : in std_logic; -- Serial Data Input
        SER_DIN_VALID   : in std_logic; -- Valid signal for serial input
        PAR_DOUT        : out std_logic_vector (G_DATA_BITS_W_PARITY-2 downto 0); -- Parallel Data Output
        PAR_DOUT_VALID  : out std_logic; -- Valid signal for parallel output
        PARITY_ERROR    : out std_logic -- Output indicating parity error
        );
end entity;

architecture behave of serial_to_parallel is
    signal shift_reg : std_logic_vector (G_DATA_BITS_W_PARITY-1 downto 0) := (others =>'0') ; -- Shift register for serial to parallel conversion
    signal parity_check : std_logic := '0'; -- Parity check signal
    signal ser_din_valid_d1 : std_logic := '0' ; -- Delayed version of SER_DIN_VALID for detecting falling edge
    signal par_dout_valid_int : std_logic := '0'; -- Internal signal for managing parallel output validity

begin

    process (CLK , RST)
    begin
        if RST = '1' then
            -- Reset values
            PAR_DOUT <= (others => '0');
            PAR_DOUT_VALID <= '0';
            PARITY_ERROR <= '0';
            shift_reg <= (others => '0') ;
            parity_check <= '0' ;
            ser_din_valid_d1 <= '0';
        elsif rising_edge(CLK) then
            -- On rising edge of clock
            ser_din_valid_d1 <= SER_DIN_VALID;
            PAR_DOUT_VALID <= '0';

            if SER_DIN_VALID = '1' then
                -- If valid serial data
                if G_LSB_FIRST = true then -- Shift in serial data, considering LSB or MSB first
                    shift_reg <= SER_DIN & shift_reg(G_DATA_BITS_W_PARITY-1 downto 1);
                else
                    shift_reg <= shift_reg(G_DATA_BITS_W_PARITY-2 downto 0) & SER_DIN;
                end if;
                parity_check <= parity_check xor SER_DIN; -- Update parity check
            else
                -- If no valid serial data, use predefined parity value
                parity_check <= G_PARITY ;
            end if;
            
            if par_dout_valid_int = '1' then
                -- Output parallel data on valid signal
                PAR_DOUT <= shift_reg(G_DATA_BITS_W_PARITY-1 downto 1); -- Output parallel data without parity bit
                PAR_DOUT_VALID <= '1'; -- Set parallel output valid
                PARITY_ERROR <= parity_check; -- Output parity error
            end if;

        end if;    
    end process;
    par_dout_valid_int <= not(SER_DIN_VALID) and ser_din_valid_d1; -- Detect falling edge of SER_DIN_VALID to set par_dout_valid_int

end behave;
