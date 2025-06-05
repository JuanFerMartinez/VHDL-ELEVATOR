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

-- ======================= ENTIDAD PRINCIPAL =======================
entity top_ascensor is
    Port (
        clk_50MHz      : in  STD_LOGIC;                        -- Reloj principal a 50 MHz
        llamada_p1     : in  STD_LOGIC;                        -- Botón de llamada desde piso 1
        llamada_p2     : in  STD_LOGIC;                        -- Botón de llamada desde piso 2
        llamada_p3     : in  STD_LOGIC;                        -- Botón de llamada desde piso 3
        llamada_p4     : in  STD_LOGIC;                        -- Botón de llamada desde piso 4
        llamada_p5     : in  STD_LOGIC;                        -- Botón de llamada desde piso 5
        abrir_manual   : in  STD_LOGIC;                        -- Botón para apertura manual de puerta
        cerrar_manual  : in  STD_LOGIC;                        -- Botón para cierre manual de puerta
        personas_sw    : in  STD_LOGIC_VECTOR(3 downto 0);     -- Cantidad de personas (0-15)
        corte_energia  : in  STD_LOGIC;                        -- Entrada de corte de energía (1 = apagado)
        sensor_ir      : in  STD_LOGIC;                        -- Sensor IR FC-51 (0 = obstáculo detectado)
        pwm_out_motor  : out STD_LOGIC;                        -- Salida PWM para motor principal
        pwm_out_puerta : out STD_LOGIC;                        -- Salida PWM para servo de puerta
        seg_p          : out STD_LOGIC_VECTOR(6 downto 0);     -- Display de 7 segmentos para letra "P"
        seg_n          : out STD_LOGIC_VECTOR(6 downto 0);     -- Display de 7 segmentos para número de piso
        ledR           : out STD_LOGIC;                        -- LED rojo encendido en alarma o detección IR
        buzzer         : out STD_LOGIC;                        -- Buzzer encendido si hay alarma
        ledA           : out STD_LOGIC                         -- LED ámbar encendido si se mueve o hay personas
    );
end top_ascensor;

-- ======================= ARQUITECTURA =======================
architecture Behavioral of top_ascensor is

    -- Declaración de señales internas omitida por brevedad

begin

    -- Conversión del número de personas desde entrada binaria
    num_personas <= CONV_INTEGER(personas_sw);

    -- Instanciación de componentes
    -- (omitiendo detalles para enfocarnos en procesos)

    -- Registro de estado actual de la FSM
    process(clk_50MHz)
    begin
        if rising_edge(clk_50MHz) then
            estado_actual <= siguiente_estado;
        end if;
    end process;

    -- Proceso de transiciones de la FSM
    process(estado_actual, piso_actual, piso_destino, contador, cont_puerta,
            num_personas, corte_energia, ram_empty, leyendo_llamada, sensor_ir)
    begin
        case estado_actual is
            when ESPERANDO =>
                -- Estado inicial: espera llamadas, verifica sobrepeso o corte
                if corte_energia = '1' then
                    siguiente_estado <= APAGADO;
                elsif num_personas > 10 then
                    siguiente_estado <= SOBREPESO;
                elsif ram_empty = '0' and leyendo_llamada = '0' then
                    siguiente_estado <= LEYENDO_RAM;
                else
                    siguiente_estado <= ESPERANDO;
                end if;

            when LEYENDO_RAM =>
                -- Leer el próximo destino desde la RAM FIFO
                siguiente_estado <= CALCULANDO;

            when CALCULANDO =>
                -- Decidir si subir o bajar
                siguiente_estado <= MOVIENDO;

            when MOVIENDO =>
                -- Movimiento del motor entre pisos
                if corte_energia = '1' then
                    siguiente_estado <= APAGADO;
                elsif contador < 200000000 then
                    siguiente_estado <= MOVIENDO;
                else
                    siguiente_estado <= ACTUALIZANDO;
                end if;

            when ACTUALIZANDO =>
                -- Actualizar piso actual después del movimiento
                siguiente_estado <= VERIFICAR;

            when VERIFICAR =>
                -- Verifica si ya se llegó al piso destino
                if piso_actual = piso_destino then
                    siguiente_estado <= ABRIENDO_PUERTA;
                else
                    siguiente_estado <= CALCULANDO;
                end if;

            when ABRIENDO_PUERTA =>
                -- Inicia la apertura de puerta
                siguiente_estado <= ESPERANDO_PUERTA;

            when ESPERANDO_PUERTA =>
                -- Espera con puerta abierta, no permite cierre si el sensor IR detecta
                if cont_puerta < 250000000 or sensor_ir = '0' then
                    siguiente_estado <= ESPERANDO_PUERTA;
                else
                    siguiente_estado <= CERRANDO_PUERTA;
                end if;

            when CERRANDO_PUERTA =>
                -- Comienza a cerrar la puerta
                siguiente_estado <= ESPERANDO;

            when SOBREPESO =>
                -- Espera que se normalice el número de personas
                if num_personas <= 10 then
                    siguiente_estado <= ESPERANDO;
                else
                    siguiente_estado <= SOBREPESO;
                end if;

            when APAGADO =>
                -- En estado de corte de energía
                if corte_energia = '0' then
                    if volver_a_mover = '1' then
                        siguiente_estado <= MOVIENDO;
                    else
                        siguiente_estado <= ESPERANDO;
                    end if;
                else
                    siguiente_estado <= APAGADO;
                end if;

            when others =>
                siguiente_estado <= ESPERANDO;
        end case;
    end process;

    -- Proceso secuencial principal: controla acciones por estado
    process(clk_50MHz)
        variable destino_ram : integer range 1 to 5 := 1;
    begin
        if rising_edge(clk_50MHz) then
            case estado_actual is
                when ESPERANDO =>
                    -- Reinicia variables, lee entradas y escribe a RAM si hay nueva llamada
                    mover <= '0'; cont_puerta <= 0; ram_we <= '0'; ram_re <= '0'; leyendo_llamada <= '0';
                    if llamada_p1 = '1' and prev_p1 = '0' then ram_data_in <= "001"; ram_we <= '1';
                    elsif llamada_p2 = '1' and prev_p2 = '0' then ram_data_in <= "010"; ram_we <= '1';
                    elsif llamada_p3 = '1' and prev_p3 = '0' then ram_data_in <= "011"; ram_we <= '1';
                    elsif llamada_p4 = '1' and prev_p4 = '0' then ram_data_in <= "100"; ram_we <= '1';
                    elsif llamada_p5 = '1' and prev_p5 = '0' then ram_data_in <= "101"; ram_we <= '1';
                    end if;
                    if abrir_manual = '1' and prev_abrir = '0' then
                        puerta_abierta <= '1'; mover_puerta <= '1'; cont_puerta_pwm <= 0; cont_puerta <= 0;
                    end if;
                    if cerrar_manual = '1' and prev_cerrar = '0' then
                        puerta_abierta <= '0'; mover_puerta <= '1'; cont_puerta_pwm <= 0;
                    end if;

                when LEYENDO_RAM =>
                    -- Activa lectura de RAM y marca estado de lectura
                    ram_re <= '1'; leyendo_llamada <= '1';

                when CALCULANDO =>
                    -- Convierte destino desde RAM, calcula dirección
                    destino_ram := CONV_INTEGER(ram_data_out);
                    piso_destino <= destino_ram;
                    if destino_ram > piso_actual then subir <= '1'; else subir <= '0'; end if;
                    mover <= '1'; contador <= 0;

                when MOVIENDO =>
                    -- Motor en movimiento
                    mover <= '1'; contador <= contador + 1; contador_backup <= contador;

                when ACTUALIZANDO =>
                    -- Avanza un piso
                    mover <= '0';
                    if subir = '1' then piso_actual <= piso_actual + 1; else piso_actual <= piso_actual - 1; end if;

                when ABRIENDO_PUERTA =>
                    -- Abre la puerta
                    puerta_abierta <= '1'; mover_puerta <= '1'; cont_puerta_pwm <= 0; cont_puerta <= 0;

                when ESPERANDO_PUERTA =>
                    -- Incrementa tiempo de espera de puerta
                    cont_puerta <= cont_puerta + 1;

                when CERRANDO_PUERTA =>
                    -- Cierra la puerta
                    puerta_abierta <= '0'; mover_puerta <= '1'; cont_puerta_pwm <= 0;

                when SOBREPESO =>
                    -- Detiene movimiento si hay sobrepeso
                    mover <= '0'; mover_puerta <= '0';

                when APAGADO =>
                    -- Detiene todo en caso de corte y guarda estado
                    mover <= '0'; mover_puerta <= '0'; contador <= contador_backup; volver_a_mover <= '1';

                when others => null;
            end case;

            -- Lógica para mantener puerta abierta durante el pulso PWM necesario
            if mover_puerta = '1' then
                if cont_puerta_pwm < 50000000 then
                    cont_puerta_pwm <= cont_puerta_pwm + 1;
                else
                    mover_puerta <= '0'; cont_puerta_pwm <= 0;
                end if;
            end if;

            -- Actualización de flancos anteriores
            prev_p1 <= llamada_p1; prev_p2 <= llamada_p2; prev_p3 <= llamada_p3;
            prev_p4 <= llamada_p4; prev_p5 <= llamada_p5;
            prev_abrir <= abrir_manual; prev_cerrar <= cerrar_manual;

            -- Activación de alarma si hay sobrepeso o corte
            if estado_actual = SOBREPESO or estado_actual = APAGADO then
                alarma <= '1';
            else
                alarma <= '0';
            end if;
        end if;
    end process;

    -- === Salidas del sistema ===
    ledR <= alarma or not sensor_ir;                          -- LED rojo si hay alarma o detección IR
    buzzer <= alarma;                                         -- Buzzer activo solo si hay alarma
    ledA <= '1' when mover = '1' or num_personas > 0 else '0'; -- LED ámbar si se mueve o está ocupado

    pwm_out_motor  <= pwm_motor  when mover        = '1' else '0';
    pwm_out_puerta <= pwm_puerta when mover_puerta = '1' else '0';

end Behavioral;
