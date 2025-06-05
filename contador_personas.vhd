-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;       -- Librería estándar de lógica digital
use IEEE.STD_LOGIC_ARITH.ALL;      -- Librería para operaciones aritméticas (no estándar pero usada)
use IEEE.STD_LOGIC_UNSIGNED.ALL;   -- Permite operar STD_LOGIC_VECTOR como enteros sin signo

-- Entidad: contador_personas
-- Módulo que cuenta personas mediante dos sensores infrarrojos FC-51.
-- Incrementa si la secuencia es s1 luego s2, y decrementa si es s2 luego s1.
entity contador_personas is
    Port (
        clk     : in  STD_LOGIC;                     -- Reloj de entrada (50 MHz)
        reset   : in  STD_LOGIC;                     -- Reinicio asíncrono
        s1      : in  STD_LOGIC;                     -- Sensor 1 (activo en '0')
        s2      : in  STD_LOGIC;                     -- Sensor 2 (activo en '0')
        count   : out STD_LOGIC_VECTOR(3 downto 0)   -- Contador de personas (máx 15)
    );
end contador_personas;

architecture Behavioral of contador_personas is

    -- Tipo de datos para los estados de la máquina de estados
    type estado_type is (IDLE, DETECT_S1, DETECT_S2);
    signal estado : estado_type := IDLE;

    -- Contador de personas en formato vector de 4 bits (0 a 15)
    signal contador : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    -- Señales para dividir el reloj original de 50 MHz a uno más lento (~100 Hz)
    signal div_counter : INTEGER range 0 to 499999 := 0;
    signal clk_lento   : STD_LOGIC := '0';

    -- Registros opcionales para guardar los estados anteriores de los sensores
    signal s1_ant, s2_ant : STD_LOGIC := '1';

begin

    -- Proceso: divisor de reloj
    -- Genera una señal de reloj más lenta (100 Hz aprox.) para estabilizar la lectura de sensores
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

    -- Proceso: máquina de estados finitos (FSM)
    -- Controla el flujo del conteo dependiendo de las transiciones de los sensores
    process(clk_lento)
    begin
        if rising_edge(clk_lento) then
            if reset = '1' then
                -- Reinicio del sistema: contador y estado
                estado <= IDLE;
                contador <= (others => '0');
            else
                case estado is
                    when IDLE =>
                        -- Espera una detección inicial
                        if s1 = '0' and s2 = '1' then
                            estado <= DETECT_S1;  -- Posible entrada
                        elsif s2 = '0' and s1 = '1' then
                            estado <= DETECT_S2;  -- Posible salida
                        end if;

                    when DETECT_S1 =>
                        -- Espera la activación de s2 tras s1 (confirmación de entrada)
                        if s2 = '0' then
                            if contador < "1111" then
                                contador <= contador + 1;  -- Incrementa si no ha llegado al tope
                            end if;
                            estado <= IDLE;
                        elsif s1 = '1' then
                            estado <= IDLE;  -- Cancelación si s1 se desactiva sin que s2 lo siga
                        end if;

                    when DETECT_S2 =>
                        -- Espera la activación de s1 tras s2 (confirmación de salida)
                        if s1 = '0' then
                            if contador > "0000" then
                                contador <= contador - 1;  -- Decrementa si no está en cero
                            end if;
                            estado <= IDLE;
                        elsif s2 = '1' then
                            estado <= IDLE;  -- Cancelación si s2 se desactiva sin que s1 lo siga
                        end if;

                    when others =>
                        estado <= IDLE;  -- Seguridad
                end case;
            end if;

            -- Guardar estados anteriores de sensores (útil para debug si se desea)
            s1_ant <= s1;
            s2_ant <= s2;
        end if;
    end process;

    -- Asignación final del valor del contador a la salida
    count <= contador;

end Behavioral;
