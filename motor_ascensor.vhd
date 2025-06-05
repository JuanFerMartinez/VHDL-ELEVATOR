-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;       -- Librería estándar de lógica digital
use IEEE.STD_LOGIC_ARITH.ALL;      -- Librería para operaciones aritméticas
use IEEE.STD_LOGIC_UNSIGNED.ALL;   -- Permite trabajar con STD_LOGIC_VECTOR como enteros sin signo

-- Entidad: motor_ascensor
-- Genera una señal PWM para controlar un motor de ascensor mediante servomotor.
-- El ancho del pulso determina si el motor sube o baja.
entity motor_ascensor is
    Port (
        clk          : in  STD_LOGIC;      -- Reloj de entrada (50 MHz)
        reset        : in  STD_LOGIC;      -- Señal de reinicio asíncrono
        subir        : in  STD_LOGIC;      -- Dirección del movimiento: '1' = subir, '0' = bajar
        pwm_motor    : out STD_LOGIC       -- Señal PWM para el servo o motor controlado
    );
end motor_ascensor;

architecture Behavioral of motor_ascensor is
    -- Contador para generar el ciclo PWM de 20 ms (1.000.000 ciclos con clk = 50 MHz)
    signal contador     : integer range 0 to 1000000 := 0;

    -- Ancho del pulso (duty cycle) del PWM: 
    -- 50000 = 1 ms (bajar), 75000 = neutro, 100000 = 2 ms (subir)
    signal ancho_pulso  : integer := 75000;
begin

    -- Proceso que actualiza el ancho del pulso y cuenta el tiempo para el PWM
    process(clk, reset)
    begin
        if reset = '1' then
            -- Reinicio de sistema: valores iniciales
            contador <= 0;
            ancho_pulso <= 75000;  -- Pulso neutro al iniciar
        elsif rising_edge(clk) then
            -- Determinar ancho del pulso dependiendo de la señal 'subir'
            if subir = '1' then
                ancho_pulso <= 100000;  -- 2 ms: dirección subir
            else
                ancho_pulso <= 50000;   -- 1 ms: dirección bajar
            end if;

            -- Contador que determina el periodo completo del PWM (20 ms)
            if contador < 1000000 then
                contador <= contador + 1;
            else
                contador <= 0;
            end if;
        end if;
    end process;

    -- Salida PWM: pulso activo ('1') si el contador está dentro del ancho de pulso definido
    pwm_motor <= '1' when contador < ancho_pulso else '0';

end Behavioral;
