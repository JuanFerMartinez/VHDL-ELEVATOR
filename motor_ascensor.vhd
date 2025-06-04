library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity motor_ascensor is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        subir        : in  STD_LOGIC;  -- '1' para subir, '0' para bajar
        pwm_motor    : out STD_LOGIC
    );
end motor_ascensor;

architecture Behavioral of motor_ascensor is
    signal contador     : integer range 0 to 1000000 := 0;
    signal ancho_pulso  : integer := 75000; -- neutro

begin
    process(clk, reset)
    begin
        if reset = '1' then
            contador <= 0;
            ancho_pulso <= 75000; -- neutro
        elsif rising_edge(clk) then
            -- Ajustar ancho del pulso según dirección
            if subir = '1' then
                ancho_pulso <= 100000; -- subir (2 ms)
            else
                ancho_pulso <= 50000; -- bajar (1 ms)
            end if;

            -- Generar PWM
            if contador < 1000000 then
                contador <= contador + 1;
            else
                contador <= 0;
            end if;
        end if;
    end process;

    pwm_motor <= '1' when contador < ancho_pulso else '0';

end Behavioral;
