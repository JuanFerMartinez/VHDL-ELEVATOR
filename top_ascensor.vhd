-- ============================================================================
-- ARCHIVO / FILE: top_ascensor.vhd
-- DESCRIPCIÓN / DESCRIPTION: 
--   Control principal de ascensor de 5 pisos con control de motor,
--   puerta, visualización, sobrepeso, llamadas en RAM y sensor IR.
--   Compatible con sensor IR FC-51 (activo bajo).
-- 
--   Main control for a 5-floor elevator with motor control,
--   door servo, display, overweight detection, RAM-based queue, and IR sensor.
--   Supports FC-51 IR sensor (active low).
--
-- AUTOR / AUTHOR: Juan Fernando Martínez Ruiz © 2025
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity top_ascensor is
    Port (
        clk_50MHz      : in  STD_LOGIC;                        -- Reloj principal del sistema
        llamada_p1     : in  STD_LOGIC;                        -- Botón de llamada desde piso 1
        llamada_p2     : in  STD_LOGIC;                        -- Botón de llamada desde piso 2
        llamada_p3     : in  STD_LOGIC;                        -- Botón de llamada desde piso 3
        llamada_p4     : in  STD_LOGIC;                        -- Botón de llamada desde piso 4
        llamada_p5     : in  STD_LOGIC;                        -- Botón de llamada desde piso 5
        abrir_manual   : in  STD_LOGIC;                        -- Botón de apertura manual de puerta
        cerrar_manual  : in  STD_LOGIC;                        -- Botón de cierre manual de puerta
        personas_sw    : in  STD_LOGIC_VECTOR(3 downto 0);     -- Número de personas en binario (4 bits)
        corte_energia  : in  STD_LOGIC;                        -- Corte de energía (1 = apagado)
        sensor_ir      : in  STD_LOGIC;                        -- Sensor IR FC-51 (0 = detecta obstáculo)
        pwm_out_motor  : out STD_LOGIC;                        -- Salida PWM para motor principal
        pwm_out_puerta : out STD_LOGIC;                        -- Salida PWM para servo de puerta
        seg_p          : out STD_LOGIC_VECTOR(6 downto 0);     -- Segmentos 7seg para letra "P"
        seg_n          : out STD_LOGIC_VECTOR(6 downto 0);     -- Segmentos 7seg para número del piso
        ledR           : out STD_LOGIC;                        -- LED rojo: alarma o sensor IR
        buzzer         : out STD_LOGIC;                        -- Buzzer activo en caso de alarma
        ledA           : out STD_LOGIC                         -- LED amarillo: encendido cuando se mueve o hay personas
    );
end top_ascensor;

architecture Behavioral of top_ascensor is

    --------------------------------------------------------------------------
    -- SEÑALES INTERNAS
    --------------------------------------------------------------------------

    signal pwm_motor        : STD_LOGIC;        -- Señal PWM generada por el motor del ascensor
    signal pwm_puerta       : STD_LOGIC;        -- Señal PWM generada por el servo de la puerta
    signal subir            : STD_LOGIC := '1'; -- Dirección del motor ('1' subir, '0' bajar)
    signal mover            : STD_LOGIC := '0'; -- Activa el movimiento del motor
    signal mover_puerta     : STD_LOGIC := '0'; -- Activa el movimiento del servo de puerta
    signal puerta_abierta   : STD_LOGIC := '0'; -- Estado de la puerta ('1' abierta, '0' cerrada)
    signal piso_actual      : integer range 1 to 5 := 1;  -- Piso en el que se encuentra el ascensor
    signal piso_destino     : integer range 1 to 5 := 1;  -- Próximo piso al que debe ir
    signal contador         : integer range 0 to 200000000 := 0; -- Cuenta para tiempo de movimiento
    signal cont_puerta      : integer range 0 to 250000000 := 0; -- Cuenta para tiempo de espera con puerta abierta
    signal cont_puerta_pwm  : integer range 0 to 50000000 := 0;  -- Cuenta para duración de señal PWM
    signal num_personas     : integer range 0 to 15 := 0;        -- Número de personas (convertido de personas_sw)
    signal contador_backup  : integer range 0 to 200000000 := 0; -- Copia del contador para reinicio tras apagado
    signal volver_a_mover   : STD_LOGIC := '0';   -- Marca si debe continuar movimiento tras apagado
    signal alarma           : STD_LOGIC := '0';   -- Estado de alarma (por sobrepeso o corte)
    signal prev_p1, prev_p2, prev_p3, prev_p4, prev_p5 : STD_LOGIC := '0'; -- Flancos anteriores de botones
    signal prev_abrir, prev_cerrar : STD_LOGIC := '0'; -- Flancos anteriores de abrir/cerrar
    signal ram_we, ram_re : STD_LOGIC := '0'; -- Señales de control de RAM (escritura y lectura)
    signal ram_data_in : STD_LOGIC_VECTOR(2 downto 0); -- Piso solicitado a almacenar
    signal ram_data_out : STD_LOGIC_VECTOR(2 downto 0);-- Piso extraído desde la RAM
    signal ram_empty, ram_full : STD_LOGIC; -- Estado de la memoria RAM FIFO
    signal leyendo_llamada : STD_LOGIC := '0'; -- Marca si se está procesando un piso leído de la RAM

    --------------------------------------------------------------------------
    -- DEFINICIÓN DE ESTADOS DEL SISTEMA (FSM)
    --------------------------------------------------------------------------

    type estado_ascensor is (
        ESPERANDO,         -- Espera nuevas llamadas
        LEYENDO_RAM,       -- Lectura de RAM para obtener próximo piso
        CALCULANDO,        -- Cálculo de dirección (sube o baja)
        MOVIENDO,          -- Movimiento hacia el piso
        ACTUALIZANDO,      -- Actualiza piso actual
        VERIFICAR,         -- Verifica si llegó al destino
        ABRIENDO_PUERTA,   -- Activa apertura de puerta
        ESPERANDO_PUERTA,  -- Espera con puerta abierta
        CERRANDO_PUERTA,   -- Cierra puerta
        SOBREPESO,         -- Más de 10 personas
        APAGADO            -- Corte de energía
    );
    signal estado_actual, siguiente_estado : estado_ascensor := ESPERANDO;

    --------------------------------------------------------------------------
    -- COMPONENTES USADOS
    --------------------------------------------------------------------------

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

    --------------------------------------------------------------------------
    -- INICIO DE IMPLEMENTACIÓN
    --------------------------------------------------------------------------

begin

    -- Conversión del número de personas desde 4 bits a entero
    num_personas <= CONV_INTEGER(personas_sw);

    -- Instanciación de módulos
    U1: motor_ascensor   port map (clk => clk_50MHz, reset => '0', subir => subir, pwm_motor => pwm_motor);
    U2: motor_puerta     port map (clk => clk_50MHz, reset => '0', puerta_abierta => puerta_abierta, pwm_servo => pwm_puerta);
    U3: display_7seg_piso port map (piso_actual => piso_actual, display_p => seg_p, display_n => seg_n);
    U4: ram_llamadas     port map (clk => clk_50MHz, reset => '0', we => ram_we, re => ram_re,
                                   data_in => ram_data_in, data_out => ram_data_out, empty => ram_empty, full => ram_full);

    -- Máquina de estados: actualiza el estado actual cada flanco de reloj
    process(clk_50MHz)
    begin
        if rising_edge(clk_50MHz) then
            estado_actual <= siguiente_estado;
        end if;
    end process;

    -- Lógica de transición entre estados
    process(estado_actual, piso_actual, piso_destino, contador, cont_puerta, num_personas,
            corte_energia, ram_empty, leyendo_llamada, sensor_ir)
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

            when LEYENDO_RAM      => siguiente_estado <= CALCULANDO;
            when CALCULANDO       => siguiente_estado <= MOVIENDO;
            when MOVIENDO         => if corte_energia = '1' then siguiente_estado <= APAGADO;
                                     elsif contador < 200000000 then siguiente_estado <= MOVIENDO;
                                     else siguiente_estado <= ACTUALIZANDO; end if;
            when ACTUALIZANDO     => siguiente_estado <= VERIFICAR;
            when VERIFICAR        => if piso_actual = piso_destino then siguiente_estado <= ABRIENDO_PUERTA;
                                     else siguiente_estado <= CALCULANDO; end if;
            when ABRIENDO_PUERTA  => siguiente_estado <= ESPERANDO_PUERTA;

            -- ⚠️ Sensor IR impide cierre si detecta obstáculo (sensor_ir = '0')
            when ESPERANDO_PUERTA =>
                if cont_puerta < 250000000 or sensor_ir = '0' then
                    siguiente_estado <= ESPERANDO_PUERTA;
                else
                    siguiente_estado <= CERRANDO_PUERTA;
                end if;

            when CERRANDO_PUERTA  => siguiente_estado <= ESPERANDO;
            when SOBREPESO        => if num_personas <= 10 then siguiente_estado <= ESPERANDO;
                                     else siguiente_estado <= SOBREPESO; end if;
            when APAGADO          => if corte_energia = '0' then
                                         if volver_a_mover = '1' then siguiente_estado <= MOVIENDO;
                                         else siguiente_estado <= ESPERANDO; end if;
                                     else siguiente_estado <= APAGADO;
                                     end if;
            when others           => siguiente_estado <= ESPERANDO;
        end case;
    end process;

    -- TODO EL RESTO (se mantiene sin cambios y se puede usar tal como está en tu código actual)
    -- Solo recuerda: las señales `ledR` y FSM `ESPERANDO_PUERTA` ya tienen el comportamiento invertido del sensor

    --------------------------------------------------------------------------
    -- Salidas de estado (resumen)
    --------------------------------------------------------------------------

    -- LED rojo se enciende si hay alarma o si el sensor detecta obstáculo (sensor_ir = '0')
    ledR <= alarma or not sensor_ir;

    -- Buzzer activado solo por alarma
    buzzer <= alarma;

    -- LED amarillo indica si el ascensor se mueve o hay personas dentro
    ledA <= '1' when mover = '1' or num_personas > 0 else '0';

    -- Salidas PWM habilitadas según flags
    pwm_out_motor  <= pwm_motor  when mover        = '1' else '0';
    pwm_out_puerta <= pwm_puerta when mover_puerta = '1' else '0';

end Behavioral;
