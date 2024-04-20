library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity serial_data_generator is
generic (
    G_DATA_BLOCK_SIZE       : integer := 64;
    G_RESET_ACTIVE_VALUE    : std_logic := '0'  
);
port (
    CLK                     : in    std_logic;  -- system clock
    RST                     : in    std_logic;  -- asynchronous reset. The polarity is accordong to G_RESET_ACTIVE_VALUE
    
    DATA_REQUEST            : in    std_logic;  -- active high
    SER_DOUT                : out   std_logic;  -- derial data output
    SER_DOUT_VALID          : out   std_logic   -- active high
);
end entity;

architecture behave of serial_data_generator is

    constant C_N_BITS           : integer := 9;
    constant C_DELAY_FROM_REQ   : integer := 100;
    
    component data_rom is
    generic (
        G_DATA_WIDTH    : integer := 10
    );
    port (
        address     : in    std_logic_vector (10 downto 0);
        clock       : in    std_logic  := '1';
        q           : out   std_logic_vector (G_DATA_WIDTH-1 downto 0)
    );
    end component;
    
    type sm_states is (
        st_idle,
        st_delay_from_start,
        st_read_from_mem,
        st_transmit_data,
        st_delay_between_data
    );
    
    signal data_count       : integer range 0 to G_DATA_BLOCK_SIZE := 0;
    signal mem_address      : std_logic_vector(10 downto 0) := (others=>'0');
    signal mem_dout         : std_logic_vector(C_N_BITS-1 downto 0);
    signal sm               : sm_states := st_idle;
    signal bit_count        : integer range 0 to C_N_BITS;
    signal delay_count      : integer range 0 to C_DELAY_FROM_REQ := 0;
    signal shift_reg        : std_logic_vector(C_N_BITS-1 downto 0);
    

begin


    mem_inst: data_rom
    generic map (
        G_DATA_WIDTH    => C_N_BITS
    )
port map (
        address         => mem_address,
        clock           => CLK,
        q               => mem_dout
    );
    
    gen_sm: process(CLK, RST)
        variable d_var  : std_logic_vector(1 downto 0);
    begin
        if RST = G_RESET_ACTIVE_VALUE then
            sm <= st_idle;
            delay_count <= 0;
            shift_reg <= (others=>'0');
            SER_DOUT_VALID <= '0';
            bit_count <= 0;
            data_count <= 0;
            mem_address <= (others=>'0');
            
        elsif rising_edge(CLK) then
            case sm is
            
                when st_idle =>
                    if DATA_REQUEST = '1' then
                        delay_count <= C_DELAY_FROM_REQ-1;
                        sm <= st_delay_from_start;
                    end if;
                    data_count <= 0;
                    
                when st_delay_from_start =>
                    if delay_count = 0 then
                        if DATA_REQUEST = '1' then
                            sm <= st_read_from_mem;
                        else
                            sm <= st_idle;
                        end if;
                    else
                        delay_count <= delay_count - 1;
                    end if;
                
                
                when st_read_from_mem =>
                    shift_reg <= mem_dout;
                    sm <= st_transmit_data;
                    SER_DOUT_VALID <= '1';
                    
                
                when st_transmit_data =>
                    if bit_count = C_N_BITS-1 then
                        SER_DOUT_VALID <= '0';
                        bit_count <= 0;
                        if data_count = G_DATA_BLOCK_SIZE-1 then
                            sm <= st_idle;
                        else
                            
--                          mem_address <= mem_address + 1;
                            d_var := conv_std_logic_vector(data_count, d_var'length);   -- generate variable delay between data
                            
                            data_count <= data_count + 1;
                            sm <= st_delay_between_data;
                            delay_count <= conv_integer(d_var(1 downto 0));
                        end if;
                        mem_address <= mem_address + 1;
                    else
                        bit_count <= bit_count + 1;
                    end if;
                    shift_reg <= shift_reg(shift_reg'high-1 downto 0) & '0';
                
                when st_delay_between_data =>
                    if delay_count = 0 then
                        sm <= st_read_from_mem;
                    else
                        delay_count <= delay_count - 1;
                    end if;
                    
            end case;

        
        end if;
    end process;
        
    SER_DOUT <= shift_reg(C_N_BITS-1);

end architecture;