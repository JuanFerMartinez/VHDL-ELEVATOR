-- ============================================================================
-- ARCHIVO: motor_ascensor.vhd
-- DESCRIPCIÓN: Módulo para generar una señal PWM de control de dirección 
--              para un motor (o servo) que mueve el ascensor. La duración del 
--              pulso determina la dirección del movimiento: subir o bajar.
-- AUTOR: Juan Fernando Martínez Ruiz © 2025
-- ============================================================================

-- ============================================================================
-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;       -- Librería de lógica digital estándar
use IEEE.STD_LOGIC_ARITH.ALL;      -- Librería para operaciones aritméticas extendidas
use IEEE.STD_LOGIC_UNSIGNED.ALL;   -- Permite operaciones con vectores como enteros sin signo

-- ======================= ENTIDAD =======================
-- Módulo que genera un pulso PWM de 20 ms de período (frecuencia 50 Hz)
-- para controlar la dirección de movimiento del motor del ascensor.
entity motor_ascensor is
    Port (
        clk          : in  STD_LOGIC;      -- Señal de reloj del sistema (50 MHz)
        reset        : in  STD_LOGIC;      -- Reinicio asíncrono del sistema
        subir        : in  STD_LOGIC;      -- Dirección del movimiento: 
                                           -- '1' = subir (2 ms), '0' = bajar (1 ms)
        pwm_motor    : out STD_LOGIC       -- Salida PWM hacia el controlador del motor
    );
end motor_ascensor;

-- ======================= ARQUITECTURA =======================
architecture Behavioral of motor_ascensor is

    -- ======================= SEÑALES INTERNAS =======================
    -- Contador para determinar el ciclo completo de 20 ms (20 ms × 50 MHz = 1 000 000 ciclos)
    signal contador     : integer range 0 to 1000000 := 0;

    -- Variable que representa el tiempo activo del pulso PWM dentro del periodo:
    --  50000 ciclos (1 ms): bajar
    -- 100000 ciclos (2 ms): subir
    signal ancho_pulso  : integer := 75000;  -- Valor inicial neutro

begin

    -- ======================= PROCESO DE PWM =======================
    -- Este proceso actualiza el ancho del pulso de la señal PWM en cada flanco de reloj
    process(clk, reset)
    begin
        if reset = '1' then
            -- Estado de reinicio del sistema
            contador <= 0;
            ancho_pulso <= 75000;  -- Neutro (1.5 ms)
        elsif rising_edge(clk) then
            -- Selección del ancho de pulso según la dirección del movimiento
            if subir = '1' then
                ancho_pulso <= 100000;  -- Subir: pulso de 2 ms
            else
                ancho_pulso <= 50000;   -- Bajar: pulso de 1 ms
            end if;

            -- Actualización del contador dentro del periodo de 20 ms
            if contador < 1000000 then
                contador <= contador + 1;
            else
                contador <= 0;
            end if;
        end if;
    end process;

    -- ======================= SALIDA PWM =======================
    -- La señal pwm_motor se mantiene en '1' mientras el contador esté dentro del ancho del pulso
    pwm_motor <= '1' when contador < ancho_pulso else '0';

end Behavioral;
