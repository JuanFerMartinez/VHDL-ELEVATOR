-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ram_llamadas is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        we         : in  STD_LOGIC;  -- write enable
        re         : in  STD_LOGIC;  -- read enable
        data_in    : in  STD_LOGIC_VECTOR(2 downto 0); -- piso 1 a 5
        data_out   : out STD_LOGIC_VECTOR(2 downto 0);
        empty      : out STD_LOGIC;
        full       : out STD_LOGIC
    );
end ram_llamadas;

architecture Behavioral of ram_llamadas is
    type ram_type is array (0 to 7) of STD_LOGIC_VECTOR(2 downto 0); -- 8 posiciones
    signal ram       : ram_type := (others => (others => '0'));
    signal wr_ptr    : integer range 0 to 7 := 0;
    signal rd_ptr    : integer range 0 to 7 := 0;
    signal count     : integer range 0 to 8 := 0;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                wr_ptr <= 0;
                rd_ptr <= 0;
                count  <= 0;
            else
                if we = '1' and count < 8 then
                    ram(wr_ptr) <= data_in;
                    wr_ptr <= (wr_ptr + 1) mod 8;
                    count <= count + 1;
                end if;

                if re = '1' and count > 0 then
                    data_out <= ram(rd_ptr);
                    rd_ptr <= (rd_ptr + 1) mod 8;
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;

    empty <= '1' when count = 0 else '0';
    full  <= '1' when count = 8 else '0';

end Behavioral;
