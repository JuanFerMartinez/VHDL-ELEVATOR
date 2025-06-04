library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity top_ascensor is
    Port (
        clk_50MHz      : in  STD_LOGIC; -- Reloj del sistema / System clock (50 MHz)
        llamada_p1     : in  STD_LOGIC; -- Llamada desde el piso 1 / Call from floor 1
        llamada_p2     : in  STD_LOGIC; -- Llamada desde el piso 2 / Call from floor 2
        llamada_p3     : in  STD_LOGIC; -- Llamada desde el piso 3 / Call from floor 3
        llamada_p4     : in  STD_LOGIC; -- Llamada desde el piso 4 / Call from floor 4
        llamada_p5     : in  STD_LOGIC; -- Llamada desde el piso 5 / Call from floor 5
        abrir_manual   : in  STD_LOGIC; -- Botón para abrir la puerta manualmente / Manual door open button
        cerrar_manual  : in  STD_LOGIC; -- Botón para cerrar la puerta manualmente / Manual door close button
        personas_sw    : in  STD_LOGIC_VECTOR(3 downto 0); -- Cantidad de personas (por switches) / Number of people (via switches)
        corte_energia  : in  STD_LOGIC; -- Señal de corte de energía / Power outage signal
        pwm_out_motor  : out STD_LOGIC; -- Salida PWM del motor principal / Main motor PWM output
        pwm_out_puerta : out STD_LOGIC; -- Salida PWM del motor de la puerta / Door motor PWM output
        seg_p          : out STD_LOGIC_VECTOR(6 downto 0); -- Display para letra P / Display for letter P
        seg_n          : out STD_LOGIC_VECTOR(6 downto 0); -- Display para número de piso / Display for floor number
        ledR           : out STD_LOGIC; -- LED rojo para alerta / Red LED for alerts
        buzzer         : out STD_LOGIC; -- Zumbador para alerta sonora / Buzzer for audible alert
        ledA           : out STD_LOGIC  -- LED amarillo para indicar movimiento / Yellow LED indicating movement
    );
end top_ascensor;

architecture Behavioral of top_ascensor is

    -- Señales internas / Internal signals
    signal pwm_motor        : STD_LOGIC;
    signal pwm_puerta       : STD_LOGIC;
    signal subir            : STD_LOGIC := '1';  -- Dirección de movimiento / Movement direction
    signal mover            : STD_LOGIC := '0';  -- Activar movimiento / Move elevator
    signal mover_puerta     : STD_LOGIC := '0';  -- Activar movimiento de puerta / Move door
    signal puerta_abierta   : STD_LOGIC := '0';  -- Estado de puerta / Door open status
    signal piso_actual      : integer range 1 to 5 := 1;  -- Piso actual / Current floor
    signal piso_destino     : integer range 1 to 5 := 1;  -- Piso destino / Destination floor
    signal contador         : integer range 0 to 200000000 := 0; -- Tiempo de movimiento / Movement timer
    signal cont_puerta      : integer range 0 to 250000000 := 0; -- Tiempo de puerta abierta / Door wait timer
    signal cont_puerta_pwm  : integer range 0 to 50000000 := 0; -- Tiempo PWM puerta / PWM duration for door
    signal num_personas     : integer range 0 to 15 := 0; -- Cantidad de personas / People count
    signal contador_backup  : integer range 0 to 200000000 := 0; -- Backup de contador / Movement timer backup
    signal volver_a_mover   : STD_LOGIC := '0'; -- Indica si debe continuar moviendo / Resume move flag
    signal alarma           : STD_LOGIC := '0'; -- Señal de alarma / Alarm signal
    signal prev_p1, prev_p2, prev_p3, prev_p4, prev_p5 : STD_LOGIC := '0'; -- Flancos de subida / Rising edge detection
    signal prev_abrir, prev_cerrar : STD_LOGIC := '0'; -- Flancos para abrir/cerrar / Rising edge open/close
    signal ram_we, ram_re : STD_LOGIC := '0'; -- Escritura/lectura RAM / RAM write/read
    signal ram_data_in : STD_LOGIC_VECTOR(2 downto 0); -- Entrada a RAM / RAM data input
    signal ram_data_out : STD_LOGIC_VECTOR(2 downto 0); -- Salida de RAM / RAM data output
    signal ram_empty, ram_full : STD_LOGIC; -- Flags de RAM vacía/llena / RAM status flags
    signal leyendo_llamada : STD_LOGIC := '0'; -- Flag de lectura de llamada / Reading call flag

    -- Definición de estados / State definition
    type estado_ascensor is (
        ESPERANDO, LEYENDO_RAM, CALCULANDO, MOVIENDO, ACTUALIZANDO,
        VERIFICAR, ABRIENDO_PUERTA, ESPERANDO_PUERTA, CERRANDO_PUERTA, SOBREPESO, APAGADO
    );
    signal estado_actual, siguiente_estado : estado_ascensor := ESPERANDO;

    -- Componentes externos / External components
    component motor_ascensor
        Port (
            clk       : in  STD_LOGIC;
            reset     : in  STD_LOGIC;
            subir     : in  STD_LOGIC;
            pwm_motor : out STD_LOGIC
        );
    end component;

    component motor_puerta
        Port (
            clk            : in  STD_LOGIC;
            reset          : in  STD_LOGIC;
            puerta_abierta : in  STD_LOGIC;
            pwm_servo      : out STD_LOGIC
        );
    end component;

    component display_7seg_piso
        Port (
            piso_actual : in  integer range 1 to 5;
            display_p   : out STD_LOGIC_VECTOR(6 downto 0);
            display_n   : out STD_LOGIC_VECTOR(6 downto 0)
        );
    end component;

    component ram_llamadas
        Port (
            clk      : in  STD_LOGIC;
            reset    : in  STD_LOGIC;
            we       : in  STD_LOGIC;
            re       : in  STD_LOGIC;
            data_in  : in  STD_LOGIC_VECTOR(2 downto 0);
            data_out : out STD_LOGIC_VECTOR(2 downto 0);
            empty    : out STD_LOGIC;
            full     : out STD_LOGIC
        );
    end component;

begin

    -- Conversión de número de personas / People count conversion
    num_personas <= CONV_INTEGER(personas_sw);

    -- Mapas de puertos / Port mappings
    U1: motor_ascensor port map (clk => clk_50MHz, reset => '0', subir => subir, pwm_motor => pwm_motor);
    U2: motor_puerta   port map (clk => clk_50MHz, reset => '0', puerta_abierta => puerta_abierta, pwm_servo => pwm_puerta);
    U3: display_7seg_piso port map (piso_actual => piso_actual, display_p => seg_p, display_n => seg_n);
    U4: ram_llamadas port map (
        clk => clk_50MHz,
        reset => '0',
        we => ram_we,
        re => ram_re,
        data_in => ram_data_in,
        data_out => ram_data_out,
        empty => ram_empty,
        full => ram_full
    );

    -- Proceso 1: Transición de estado actual / State transition process
    process(clk_50MHz)
    begin
        if rising_edge(clk_50MHz) then
            estado_actual <= siguiente_estado;
        end if;
    end process;

    -- Proceso 2: Lógica de próximo estado / Next state logic
    process(estado_actual, piso_actual, piso_destino, contador, cont_puerta, num_personas, corte_energia, ram_empty, leyendo_llamada)
    begin
        case estado_actual is
            when ESPERANDO =>
                if corte_energia = '1' then
                    siguiente_estado <= APAGADO;
                elsif num_personas > 10 then
                    siguiente_estado <= SOBREPESO;
                elsif ram_empty = '0' and leyendo_llamada = '0' then
                    siguiente_estado <= LEYENDO_RAM;
                else
                    siguiente_estado <= ESPERANDO;
                end if;
            when LEYENDO_RAM => siguiente_estado <= CALCULANDO;
            when CALCULANDO => siguiente_estado <= MOVIENDO;
            when MOVIENDO =>
                if corte_energia = '1' then
                    siguiente_estado <= APAGADO;
                elsif contador < 200000000 then
                    siguiente_estado <= MOVIENDO;
                else
                    siguiente_estado <= ACTUALIZANDO;
                end if;
            when ACTUALIZANDO => siguiente_estado <= VERIFICAR;
            when VERIFICAR =>
                if piso_actual = piso_destino then
                    siguiente_estado <= ABRIENDO_PUERTA;
                else
                    siguiente_estado <= CALCULANDO;
                end if;
            when ABRIENDO_PUERTA => siguiente_estado <= ESPERANDO_PUERTA;
            when ESPERANDO_PUERTA =>
                if cont_puerta < 250000000 then
                    siguiente_estado <= ESPERANDO_PUERTA;
                else
                    siguiente_estado <= CERRANDO_PUERTA;
                end if;
            when CERRANDO_PUERTA => siguiente_estado <= ESPERANDO;
            when SOBREPESO =>
                if num_personas <= 10 then
                    siguiente_estado <= ESPERANDO;
                else
                    siguiente_estado <= SOBREPESO;
                end if;
            when APAGADO =>
                if corte_energia = '0' then
                    if volver_a_mover = '1' then
                        siguiente_estado <= MOVIENDO;
                    else
                        siguiente_estado <= ESPERANDO;
                    end if;
                else
                    siguiente_estado <= APAGADO;
                end if;
            when others => siguiente_estado <= ESPERANDO;
        end case;
    end process;

    -- Proceso 3: Lógica secuencial de salida y control / Output and control logic
    process(clk_50MHz)
        variable destino_ram : integer range 1 to 5 := 1;
    begin
        if rising_edge(clk_50MHz) then
            case estado_actual is
                when ESPERANDO =>
                    mover <= '0'; cont_puerta <= 0; ram_we <= '0'; ram_re <= '0'; leyendo_llamada <= '0';
                    if llamada_p1 = '1' and prev_p1 = '0' then ram_data_in <= "001"; ram_we <= '1';
                    elsif llamada_p2 = '1' and prev_p2 = '0' then ram_data_in <= "010"; ram_we <= '1';
                    elsif llamada_p3 = '1' and prev_p3 = '0' then ram_data_in <= "011"; ram_we <= '1';
                    elsif llamada_p4 = '1' and prev_p4 = '0' then ram_data_in <= "100"; ram_we <= '1';
                    elsif llamada_p5 = '1' and prev_p5 = '0' then ram_data_in <= "101"; ram_we <= '1';
                    end if;
                    if abrir_manual = '1' and prev_abrir = '0' then puerta_abierta <= '1'; mover_puerta <= '1'; cont_puerta_pwm <= 0; cont_puerta <= 0; end if;
                    if cerrar_manual = '1' and prev_cerrar = '0' then puerta_abierta <= '0'; mover_puerta <= '1'; cont_puerta_pwm <= 0; end if;

                when LEYENDO_RAM => ram_re <= '1'; leyendo_llamada <= '1';
                when CALCULANDO =>
                    destino_ram := CONV_INTEGER(ram_data_out);
                    piso_destino <= destino_ram;
                    if destino_ram > piso_actual then subir <= '1'; else subir <= '0'; end if;
                    mover <= '1'; contador <= 0;
                when MOVIENDO => mover <= '1'; contador <= contador + 1; contador_backup <= contador;
                when ACTUALIZANDO =>
                    mover <= '0';
                    if subir = '1' then piso_actual <= piso_actual + 1;
                    else piso_actual <= piso_actual - 1; end if;
                when ABRIENDO_PUERTA => puerta_abierta <= '1'; mover_puerta <= '1'; cont_puerta_pwm <= 0; cont_puerta <= 0;
                when ESPERANDO_PUERTA => cont_puerta <= cont_puerta + 1;
                when CERRANDO_PUERTA => puerta_abierta <= '0'; mover_puerta <= '1'; cont_puerta_pwm <= 0;
                when SOBREPESO => mover <= '0'; mover_puerta <= '0';
                when APAGADO => mover <= '0'; mover_puerta <= '0'; contador <= contador_backup; volver_a_mover <= '1';
                when others => null;
            end case;

            -- Control del tiempo de activación PWM para la puerta / PWM activation window for door motor
            if mover_puerta = '1' then
                if cont_puerta_pwm < 50000000 then
                    cont_puerta_pwm <= cont_puerta_pwm + 1;
                else
                    mover_puerta <= '0'; cont_puerta_pwm <= 0;
                end if;
            end if;

            -- Detección de flancos para entradas manuales / Edge detection for manual inputs
            prev_p1 <= llamada_p1; prev_p2 <= llamada_p2; prev_p3 <= llamada_p3; prev_p4 <= llamada_p4; prev_p5 <= llamada_p5;
            prev_abrir <= abrir_manual; prev_cerrar <= cerrar_manual;

            -- Activación de alarma si hay corte de energía o sobrepeso / Alarm triggers
            if estado_actual = SOBREPESO or estado_actual = APAGADO then
                alarma <= '1';
            else
                alarma <= '0';
            end if;
        end if;
    end process;

    -- Asignaciones finales a salidas / Final output assignments
    ledR <= alarma;
    buzzer <= alarma;
    ledA <= '1' when mover = '1' or num_personas > 0 else '0';

    pwm_out_motor  <= pwm_motor  when mover        = '1' else '0';
    pwm_out_puerta <= pwm_puerta when mover_puerta = '1' else '0';

end Behavioral;
