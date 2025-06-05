-- Todos los derechos reservados © Juan Fernando Martínez Ruiz - Junio 2025
-- All rights reserved © Juan Fernando Martínez Ruiz - June 2025

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;       -- Lógica estándar
use IEEE.STD_LOGIC_ARITH.ALL;      -- Operaciones aritméticas (uso extendido)
use IEEE.STD_LOGIC_UNSIGNED.ALL;   -- Manejo de vectores como enteros sin signo

-- Entidad: ram_llamadas
-- Módulo que implementa una memoria FIFO circular de 8 posiciones para almacenar llamadas de piso (1 a 5)
-- Permite escritura y lectura controlada, con indicadores de lleno y vacío.
entity ram_llamadas is
    Port (
        clk        : in  STD_LOGIC;                    -- Reloj del sistema
        reset      : in  STD_LOGIC;                    -- Señal de reinicio
        we         : in  STD_LOGIC;                    -- Señal de habilitación de escritura (write enable)
        re         : in  STD_LOGIC;                    -- Señal de habilitación de lectura (read enable)
        data_in    : in  STD_LOGIC_VECTOR(2 downto 0); -- Entrada de datos (piso solicitado, codificado en 3 bits)
        data_out   : out STD_LOGIC_VECTOR(2 downto 0); -- Salida de datos (piso leido)
        empty      : out STD_LOGIC;                    -- Indicador de FIFO vacía
        full       : out STD_LOGIC                     -- Indicador de FIFO llena
    );
end ram_llamadas;

architecture Behavioral of ram_llamadas is

    -- Declaración de la memoria como arreglo de 8 posiciones de 3 bits cada una
    type ram_type is array (0 to 7) of STD_LOGIC_VECTOR(2 downto 0);
    signal ram       : ram_type := (others => (others => '0'));

    -- Punteros de lectura y escritura (ambos cíclicos de 0 a 7)
    signal wr_ptr    : integer range 0 to 7 := 0;
    signal rd_ptr    : integer range 0 to 7 := 0;

    -- Contador de elementos actuales en la memoria (0 = vacío, 8 = lleno)
    signal count     : integer range 0 to 8 := 0;

begin

    -- Proceso síncrono de lectura y escritura controlada
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                -- Reinicio de punteros y contador
                wr_ptr <= 0;
                rd_ptr <= 0;
                count  <= 0;
            else
                -- Escritura si habilitada y hay espacio
                if we = '1' and count < 8 then
                    ram(wr_ptr) <= data_in;
                    wr_ptr <= (wr_ptr + 1) mod 8;
                    count <= count + 1;
                end if;

                -- Lectura si habilitada y hay datos
                if re = '1' and count > 0 then
                    data_out <= ram(rd_ptr);
                    rd_ptr <= (rd_ptr + 1) mod 8;
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;

    -- Indicadores de estado de la FIFO
    empty <= '1' when count = 0 else '0';
    full  <= '1' when count = 8 else '0';

end Behavioral;
