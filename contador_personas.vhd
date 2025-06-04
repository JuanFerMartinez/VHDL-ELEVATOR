library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity contador_personas is
    Port (
        clk     : in  STD_LOGIC;
        reset   : in  STD_LOGIC;
        s1      : in  STD_LOGIC;  -- FC-51: 0 cuando detecta
        s2      : in  STD_LOGIC;
        count   : out STD_LOGIC_VECTOR(3 downto 0)
    );
end contador_personas;

architecture Behavioral of contador_personas is

    type estado_type is (IDLE, DETECT_S1, DETECT_S2);
    signal estado : estado_type := IDLE;

    signal contador : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');

    signal div_counter : INTEGER range 0 to 499999 := 0;
    signal clk_lento   : STD_LOGIC := '0';

    -- Registros de estado anterior
    signal s1_ant, s2_ant : STD_LOGIC := '1';

begin

    -- Divisor de reloj: 50 MHz a 100 Hz
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

    -- FSM principal
    process(clk_lento)
    begin
        if rising_edge(clk_lento) then
            if reset = '1' then
                estado <= IDLE;
                contador <= (others => '0');
            else
                case estado is
                    when IDLE =>
                        if s1 = '0' and s2 = '1' then
                            estado <= DETECT_S1;
                        elsif s2 = '0' and s1 = '1' then
                            estado <= DETECT_S2;
                        end if;

                    when DETECT_S1 =>
                        if s2 = '0' then
                            if contador < "1111" then
                                contador <= contador + 1;
                            end if;
                            estado <= IDLE;
                        elsif s1 = '1' then  -- se canceló
                            estado <= IDLE;
                        end if;

                    when DETECT_S2 =>
                        if s1 = '0' then
                            if contador > "0000" then
                                contador <= contador - 1;
                            end if;
                            estado <= IDLE;
                        elsif s2 = '1' then
                            estado <= IDLE;
                        end if;

                    when others =>
                        estado <= IDLE;
                end case;
            end if;

            -- Actualiza el estado anterior (opcional si quieres debug)
            s1_ant <= s1;
            s2_ant <= s2;
        end if;
    end process;

    count <= contador;

end Behavioral;
