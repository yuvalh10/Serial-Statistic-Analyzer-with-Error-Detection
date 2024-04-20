library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
library std;
use std.textio.all;

entity statistics_calc_tb is
end entity;

architecture behave of statistics_calc_tb is

    constant C_CLK_PRD      : time := 20 ns;

    type int_array is array(integer range <>) of integer;

    component statistics_calc is
    port (
        CLK                     : in    std_logic;  -- system clock
        RSTn                    : in    std_logic;  -- asynchronous, active high reset
        
        START                   : in    std_logic;
        DISPLAY                 : in    std_logic;
        HEX0                    : out   std_logic_vector(6 downto 0);
        HEX1                    : out   std_logic_vector(6 downto 0);
        HEX2                    : out   std_logic_vector(6 downto 0);
        HEX3                    : out   std_logic_vector(6 downto 0);
        LEDR                    : out   std_logic_vector(9 downto 5);
        LEDG                    : out   std_logic_vector(2 downto 1)
    );
    end component;

    function seg7_to_bcd(val_in: std_logic_vector(6 downto 0)) return integer is
    begin
    
        case val_in is
            when "1000000" =>
                return 0;
            when "1111001" =>
                return 1;
            when "0100100" =>
                return 2;
            when "0110000" =>
                return 3;
            when "0011001" =>
                return 4;
            when "0010010" =>
                return 5;
            when "0000010" =>
                return 6;
            when "1111000" =>
                return 7;
            when "0000000" =>
                return 8;
            when "0010000" =>
                return 9;
            when others =>
                return -1;
        end case;
    
    end function;
    
    
    signal clk          : std_logic := '0';
    signal rstn         : std_logic := '0';
    signal start        : std_logic := '1';
    signal display      : std_logic := '1';
    signal hex0         : std_logic_vector(6 downto 0);
    signal hex1         : std_logic_vector(6 downto 0);
    signal hex2         : std_logic_vector(6 downto 0);
    signal ledr         : std_logic_vector(9 downto 5);
    signal ledg         : std_logic_vector(2 downto 1);


begin

    dut: statistics_calc
    port map (
        CLK                     => clk,
        RSTn                    => rstn,
        START                   => start,
        DISPLAY                 => display,
        HEX0                    => hex0,
        HEX1                    => hex1,
        HEX2                    => hex2,
        HEX3                    => open,
        LEDR                    => ledr,
        LEDG                    => ledg
    );
    
    clk <= not clk after C_CLK_PRD / 2;
    rstn <= '0', '1' after 100 ns;
    
    process
    begin
        start <= '1';
        display <= '1';
        wait for 100 us;
        
        for i in 0 to 14 loop
            start <= '0';
            wait for 1 ms;
            start <= '1';
        
            wait for 1 ms;
            
            for j in 0 to 9 loop
                display <= '0';
                wait for 1 ms;
                display <= '1';
                wait for 200 us;
            end loop;
            
            wait for 1 ms;

            start <= '0';
            wait for 1 ms;
            start <= '1';
            
            wait for 1 ms;
            
        end loop;
        
        report "End of Simulation"
        severity failure;
        
    end process;
    
    
    verify_results: process
        variable expected_values    : int_array(0 to 4);
        file infile                 : text open read_mode is "final_results.txt";
        variable inline             : line;
        variable errors_counter     : integer := 0;
        variable param_num          : integer := 0;
        variable ones, tens, hunds  : integer := 0;
        variable dut_val            : integer := 0;
    begin
    
        readline(infile, inline); -- skip first line
        
        for i in 0 to 14 loop
            wait until falling_edge(start);
            readline(infile, inline);
            for j in 0 to 4 loop
                read(inline, expected_values(j));
            end loop;
            
            param_num := 0;
            
            for k in 0 to 9 loop
                wait until falling_edge(display);
                ones := seg7_to_bcd(hex0);
                tens := seg7_to_bcd(hex1);
                hunds := seg7_to_bcd(hex2);
                dut_val := ones + tens*10 + hunds*100;
                
                if (dut_val = expected_values(param_num)) then
                    report "Pass" & LF;
                else
                    report "Fail!  " & "Expected=" & integer'image(expected_values(param_num)) & "    Actual=" & integer'image(dut_val) & LF;
                    errors_counter := errors_counter + 1;
                end if;
                
                if param_num = 4 then
                    param_num := 0;
                else
                    param_num := param_num + 1;
                end if;
            end loop;

        end loop;
        
        report "Total errors: " & integer'image(errors_counter) & LF;
        
        wait;
    
    end process;

end architecture;
