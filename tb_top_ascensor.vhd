library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity tb_top_ascensor is
end tb_top_ascensor;

architecture sim of tb_top_ascensor is

    component top_ascensor
        Port (
            clk_50MHz      : in  STD_LOGIC;
            llamada_p1     : in  STD_LOGIC;
            llamada_p2     : in  STD_LOGIC;
            llamada_p3     : in  STD_LOGIC;
            llamada_p4     : in  STD_LOGIC;
            llamada_p5     : in  STD_LOGIC;
            abrir_manual   : in  STD_LOGIC;
            cerrar_manual  : in  STD_LOGIC;
            personas_sw    : in  STD_LOGIC_VECTOR(3 downto 0);
            corte_energia  : in  STD_LOGIC;
            pwm_out_motor  : out STD_LOGIC;
            pwm_out_puerta : out STD_LOGIC;
            seg_p          : out STD_LOGIC_VECTOR(6 downto 0);
            seg_n          : out STD_LOGIC_VECTOR(6 downto 0);
            ledR           : out STD_LOGIC;
            buzzer         : out STD_LOGIC;
            ledA           : out STD_LOGIC
        );
    end component;

    -- Señales para conectar al DUT
    signal clk             : STD_LOGIC := '0';
    signal llamada_p1      : STD_LOGIC := '0';
    signal llamada_p2      : STD_LOGIC := '0';
    signal llamada_p3      : STD_LOGIC := '0';
    signal llamada_p4      : STD_LOGIC := '0';
    signal llamada_p5      : STD_LOGIC := '0';
    signal abrir_manual    : STD_LOGIC := '0';
    signal cerrar_manual   : STD_LOGIC := '0';
    signal personas_sw     : STD_LOGIC_VECTOR(3 downto 0) := "0000";
    signal corte_energia   : STD_LOGIC := '0';
    signal pwm_out_motor   : STD_LOGIC;
    signal pwm_out_puerta  : STD_LOGIC;
    signal seg_p           : STD_LOGIC_VECTOR(6 downto 0);
    signal seg_n           : STD_LOGIC_VECTOR(6 downto 0);
    signal ledR            : STD_LOGIC;
    signal buzzer          : STD_LOGIC;
    signal ledA            : STD_LOGIC;

begin

    -- Instanciar DUT
    DUT: top_ascensor port map (
        clk_50MHz => clk,
        llamada_p1 => llamada_p1,
        llamada_p2 => llamada_p2,
        llamada_p3 => llamada_p3,
        llamada_p4 => llamada_p4,
        llamada_p5 => llamada_p5,
        abrir_manual => abrir_manual,
        cerrar_manual => cerrar_manual,
        personas_sw => personas_sw,
        corte_energia => corte_energia,
        pwm_out_motor => pwm_out_motor,
        pwm_out_puerta => pwm_out_puerta,
        seg_p => seg_p,
        seg_n => seg_n,
        ledR => ledR,
        buzzer => buzzer,
        ledA => ledA
    );

    -- Generador de reloj (50 MHz)
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 10 ns;
            clk <= '1';
            wait for 10 ns;
        end loop;
    end process;

    -- Estímulos
    stim_proc: process
    begin
        -- Inicialización
        wait for 100 ns;

        -- Simular 4 personas en el ascensor
        personas_sw <= "0100"; -- 4 personas

        -- Hacer una llamada al piso 3
        llamada_p3 <= '1';
        wait for 20 ns;
        llamada_p3 <= '0';

        -- Esperar para permitir transiciones FSM
        wait for 5 ms;

        -- Sobrecarga (más de 10 personas)
        personas_sw <= "1011"; -- 11 personas
        wait for 1 ms;

        -- Normalizar
        personas_sw <= "0011"; -- 3 personas
        wait for 2 ms;

        -- Simular corte de energía
        corte_energia <= '1';
        wait for 1 ms;

        -- Restaurar energía
        corte_energia <= '0';
        wait for 2 ms;

        -- Otra llamada al piso 5
        llamada_p5 <= '1';
        wait for 20 ns;
        llamada_p5 <= '0';

        wait for 10 ms;

        -- Fin de simulación
        wait;
    end process;

end sim;
