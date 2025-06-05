-- ============================================================================
-- ARCHIVO: ram_llamadas.vhd
-- DESCRIPCIÓN: Memoria FIFO circular de 8 posiciones para gestionar llamadas 
--              de piso (1 a 5) en el sistema de control de ascensor.
--              Permite almacenar múltiples solicitudes en orden de llegada.
-- AUTOR: Juan Fernando Martínez Ruiz © 2025
-- ============================================================================

-- ============================================================================
-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025
-- ============================================================================

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;       -- Lógica estándar
use IEEE.STD_LOGIC_ARITH.ALL;      -- Operaciones aritméticas extendidas
use IEEE.STD_LOGIC_UNSIGNED.ALL;   -- Interpretación de vectores como enteros sin signo

-- ======================= ENTIDAD =======================
-- Módulo FIFO de 8 entradas para almacenar llamadas de piso (1 a 5).
-- Controlado por reloj, con flujos de lectura y escritura independientes.
entity ram_llamadas is
    Port (
        clk        : in  STD_LOGIC;                    -- Reloj del sistema
        reset      : in  STD_LOGIC;                    -- Señal de reinicio síncrono
        we         : in  STD_LOGIC;                    -- Habilitación de escritura (Write Enable)
        re         : in  STD_LOGIC;                    -- Habilitación de lectura (Read Enable)
        data_in    : in  STD_LOGIC_VECTOR(2 downto 0); -- Piso a guardar (codificado en 3 bits)
        data_out   : out STD_LOGIC_VECTOR(2 downto 0); -- Piso leído desde FIFO
        empty      : out STD_LOGIC;                    -- Indicador de FIFO vacía
        full       : out STD_LOGIC                     -- Indicador de FIFO llena
    );
end ram_llamadas;

-- ======================= ARQUITECTURA =======================
architecture Behavioral of ram_llamadas is

    -- Tipo de dato para la RAM: arreglo de 8 palabras de 3 bits
    type ram_type is array (0 to 7) of STD_LOGIC_VECTOR(2 downto 0);
    signal ram       : ram_type := (others => (others => '0')); -- Inicialización a cero

    -- Punteros cíclicos para escritura y lectura (0 a 7)
    signal wr_ptr    : integer range 0 to 7 := 0; -- Puntero de escritura
    signal rd_ptr    : integer range 0 to 7 := 0; -- Puntero de lectura

    -- Contador de elementos almacenados en la FIFO (0: vacía, 8: llena)
    signal count     : integer range 0 to 8 := 0;

begin

    -- ======================= PROCESO PRINCIPAL =======================
    -- Manejo de escritura y lectura síncrona con el reloj
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reinicia punteros y contador en caso de reset
                wr_ptr <= 0;
                rd_ptr <= 0;
                count  <= 0;
                data_out <= (others => '0');
            else
                -- Escritura a memoria si habilitada y no llena
                if we = '1' and count < 8 then
                    ram(wr_ptr) <= data_in;
                    wr_ptr <= (wr_ptr + 1) mod 8;
                    count <= count + 1;
                end if;

                -- Lectura desde memoria si habilitada y no vacía
                if re = '1' and count > 0 then
                    data_out <= ram(rd_ptr);
                    rd_ptr <= (rd_ptr + 1) mod 8;
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;

    -- ======================= SALIDAS =======================
    empty <= '1' when count = 0 else '0'; -- FIFO vacía
    full  <= '1' when count = 8 else '0'; -- FIFO llena

end Behavioral;
