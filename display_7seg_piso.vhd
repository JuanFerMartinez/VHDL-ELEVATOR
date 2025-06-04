library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity display_7seg_piso is
    Port (
        piso_actual : in  integer range 1 to 5;
        display_p   : out STD_LOGIC_VECTOR(6 downto 0);  -- Letra "P"
        display_n   : out STD_LOGIC_VECTOR(6 downto 0)   -- Número del piso (1 a 5)
    );
end display_7seg_piso;

architecture Behavioral of display_7seg_piso is
begin

    -- Mostrar siempre la letra "P" en el display izquierdo
    display_p <= "0001100"; 

    -- Selección del número del piso en el display derecho
    process(piso_actual)
    begin
        case piso_actual is
            when 1 => display_n <= "1111001"; -- número 1
            when 2 => display_n <= "0100100"; -- número 2
            when 3 => display_n <= "0110000"; -- número 3
            when 4 => display_n <= "0011001"; -- número 4
            when 5 => display_n <= "0010010"; -- número 5
            when others => display_n <= "1111111"; -- apagado (error)
        end case;
    end process;

end Behavioral;
