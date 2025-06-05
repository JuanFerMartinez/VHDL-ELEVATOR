-- ============================================================================
-- ARCHIVO: display_7seg_piso.vhd
-- DESCRIPCIÓN: Módulo para visualizar el piso actual del ascensor en dos 
--              displays de 7 segmentos. El primero muestra la letra "P" 
--              (de "Piso") y el segundo el número del piso (1 a 5).
-- AUTOR: Juan Fernando Martínez Ruiz © 2025
-- ============================================================================

-- ============================================================================
-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL; -- Librería para lógica digital estándar

-- ======================= ENTIDAD =======================
-- Entradas:
--   - piso_actual: número del piso actual, entero de 1 a 5
-- Salidas:
--   - display_p: código de segmentos para mostrar la letra "P"
--   - display_n: código de segmentos para mostrar el número de piso (1 a 5)
entity display_7seg_piso is
    Port (
        piso_actual : in  integer range 1 to 5;               -- Número del piso actual
        display_p   : out STD_LOGIC_VECTOR(6 downto 0);       -- Segmentos para la letra "P"
        display_n   : out STD_LOGIC_VECTOR(6 downto 0)        -- Segmentos para el número (1 a 5)
    );
end display_7seg_piso;

-- ======================= ARQUITECTURA =======================
architecture Behavioral of display_7seg_piso is
begin

    -- ======================= DISPLAY LETRA "P" =======================
    -- Código en 7 segmentos para letra "P"
    -- Orden de segmentos: a b c d e f g
    -- Letra "P" = segmentos a, b, e, f, g encendidos: "0001100"
    display_p <= "0001100"; 

    -- ======================= DISPLAY NÚMERO DE PISO =======================
    -- Se selecciona el código correspondiente al número del piso
    process(piso_actual)
    begin
        case piso_actual is
            when 1 => display_n <= "1111001"; -- Número 1: segmentos b y c
            when 2 => display_n <= "0100100"; -- Número 2: a, b, g, e, d
            when 3 => display_n <= "0110000"; -- Número 3: a, b, c, d, g
            when 4 => display_n <= "0011001"; -- Número 4: f, g, b, c
            when 5 => display_n <= "0010010"; -- Número 5: a, f, g, c, d
            when others => display_n <= "1111111"; -- Apagado total si fuera inválido
        end case;
    end process;

end Behavioral;
