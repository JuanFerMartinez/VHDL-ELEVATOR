-- ============================================================================
-- ARCHIVO: contador_personas.vhd
-- DESCRIPCIÓN: Módulo que implementa un contador de personas con dos sensores
--              infrarrojos FC-51. Detecta entradas y salidas según la
--              secuencia de activación de los sensores. Usa una FSM y un 
--              divisor de reloj para estabilizar la lectura.
-- AUTOR: Juan Fernando Martínez Ruiz © 2025
-- ============================================================================

-- ============================================================================
-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;       -- Librería estándar de lógica digital
use IEEE.STD_LOGIC_ARITH.ALL;      -- Librería para operaciones aritméticas (no estándar)
use IEEE.STD_LOGIC_UNSIGNED.ALL;   -- Permite operar vectores como enteros sin signo

-- ======================= ENTIDAD =======================
-- Entradas:
--   - clk: reloj principal del sistema (50 MHz)
--   - reset: señal de reinicio
--   - s1, s2: sensores IR FC-51 (activos en bajo)
-- Salida:
--   - count: número actual de personas detectadas (máx. 15)
entity contador_personas is
    Port (
        clk     : in  STD_LOGIC;                     -- Reloj de entrada (50 MHz)
        reset   : in  STD_LOGIC;                     -- Reinicio asíncrono
        s1      : in  STD_LOGIC;                     -- Sensor 1 (activo en '0')
        s2      : in  STD_LOGIC;                     -- Sensor 2 (activo en '0')
        count   : out STD_LOGIC_VECTOR(3 downto 0)   -- Contador de personas (máx. 15)
    );
end contador_personas;

-- ======================= ARQUITECTURA =======================
architecture Behavioral of contador_personas is

    -- Estados de la FSM:
    type estado_type is (IDLE, DETECT_S1, DETECT_S2);
    signal estado : estado_type := IDLE;

    -- Contador de personas
    signal contador : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    -- Divisor de reloj para crear un pulso lento (~100 Hz)
    signal div_counter : INTEGER range 0 to 499999 := 0;
    signal clk_lento   : STD_LOGIC := '0';

    -- Variables para guardar los valores anteriores de los sensores (opcional)
    signal s1_ant, s2_ant : STD_LOGIC := '1';

begin

    -- ======================= DIVISOR DE RELOJ =======================
    -- Reduce el reloj de 50 MHz a aproximadamente 100 Hz
    process(clk)
    begin
        if rising_edge(clk) then
            if div_counter = 499999 then
                div_counter <= 0;
                clk_lento <= not clk_lento;
            else
                div_counter <= div_counter + 1;
            end if;
        end if;
    end process;

    -- ======================= FSM PARA DETECCIÓN DE ENTRADAS/SALIDAS =======================
    process(clk_lento)
    begin
        if rising_edge(clk_lento) then
            if reset = '1' then
                -- Reinicia todo el sistema
                estado <= IDLE;
                contador <= (others => '0');
            else
                case estado is
                    when IDLE =>
                        -- Espera una activación inicial
                        if s1 = '0' and s2 = '1' then
                            estado <= DETECT_S1;  -- Entrada posible
                        elsif s2 = '0' and s1 = '1' then
                            estado <= DETECT_S2;  -- Salida posible
                        end if;

                    when DETECT_S1 =>
                        -- Espera confirmación de entrada: s2 debe activarse luego de s1
                        if s2 = '0' then
                            if contador < "1111" then
                                contador <= contador + 1;  -- Incremento
                            end if;
                            estado <= IDLE;
                        elsif s1 = '1' then
                            estado <= IDLE;  -- Cancelación si s1 se suelta sin s2
                        end if;

                    when DETECT_S2 =>
                        -- Espera confirmación de salida: s1 debe activarse luego de s2
                        if s1 = '0' then
                            if contador > "0000" then
                                contador <= contador - 1;  -- Decremento
                            end if;
                            estado <= IDLE;
                        elsif s2 = '1' then
                            estado <= IDLE;  -- Cancelación si s2 se suelta sin s1
                        end if;

                    when others =>
                        estado <= IDLE; -- Seguridad ante errores
                end case;
            end if;

            -- Registro de estados previos (opcional para debug)
            s1_ant <= s1;
            s2_ant <= s2;
        end if;
    end process;

    -- ======================= SALIDA =======================
    count <= contador;

end Behavioral;
