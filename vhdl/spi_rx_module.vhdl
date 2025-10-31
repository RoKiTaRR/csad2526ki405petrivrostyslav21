library ieee;
use ieee.std_logic_1164.all;

-- Модуль приймача (MISO)
-- Відповідає за читання біт з лінії i_miso
-- та збір їх у паралельне слово.
entity spi_rx_module is
  generic (
    FRAME_BITS : integer := 8;
    CPOL       : integer := 0;
    CPHA       : integer := 0;
    MSB_FIRST  : boolean := true
  );
  port (
    i_clk    : in  std_logic;                           -- Системний такт
    i_rst_n  : in  std_logic;                           -- Скид
    i_sclk   : in  std_logic;                           -- Рівень SCLK
    i_edge   : in  std_logic;                           -- Імпульс на кожну зміну SCLK
    i_ss_n   : in  std_logic;                           -- Рівень SS_N
    i_miso   : in  std_logic;                           -- Вхід MISO
    o_dout   : out std_logic_vector(FRAME_BITS-1 downto 0); -- Вихідні дані
    o_count  : out integer range 0 to FRAME_BITS;       -- (не використовується)
    o_valid  : out std_logic                            -- 1-тактний імпульс "дані готові"
  );
end entity;

architecture rtl of spi_rx_module is
  -- Внутрішній зсувний регістр
  signal r_rx_shift_reg        : std_logic_vector(FRAME_BITS-1 downto 0) := (others=>'0');
  -- Лічильник отриманих біт
  signal r_bits_received_counter : integer range 0 to FRAME_BITS := 0;
  -- Регістр для імпульсу 'valid'
  signal r_data_valid_pulse    : std_logic := '0';

  -- Функція визначає, чи є поточний фронт SCLK "робочим" для ЧИТАННЯ (sample).
  function is_receive_edge(cpol, cpha: integer; sclk_level: std_logic) return boolean is
  begin
    if (cpol=0 and cpha=0) then     -- Mode 0: Sample on Rising
      return (sclk_level='0');      -- Rising
    elsif (cpol=0 and cpha=1) then  -- Mode 1: Sample on Falling
      return (sclk_level='1');      -- Falling
    elsif (cpol=1 and cpha=0) then  -- Mode 2: Sample on Falling
      return (sclk_level='1');      -- Falling
    else                            -- Mode 3: Sample on Rising
      return (sclk_level='0');      -- Rising
    end if;
  end;
  
begin
  o_dout  <= r_rx_shift_reg;
  o_count <= r_bits_received_counter;
  o_valid <= r_data_valid_pulse;

  -- Логіка приймача
  RX_SAMPLE_LOGIC_PROC: process(i_clk, i_rst_n)
  begin
    if i_rst_n='0' then
      r_rx_shift_reg        <= (others=>'0');
      r_bits_received_counter <= 0;
      r_data_valid_pulse    <= '0';
    elsif rising_edge(i_clk) then
      -- Скидаємо 'valid' кожного такту
      r_data_valid_pulse <= '0';

      -- Коли SS_N неактивний, скидаємо лічильник
      if i_ss_n='1' then
        r_bits_received_counter <= 0;
      
      -- Коли SS_N активний, слухаємо SCLK
      else
        -- Реагуємо тільки на зміну SCLK (сигнал 'i_edge')
        -- та перевіряємо, чи це фронт для ЧИТАННЯ
        if i_edge='1' and is_receive_edge(CPOL, CPHA, i_sclk) then
          
          -- Зсуваємо біт з MISO у регістр
          if MSB_FIRST then
            r_rx_shift_reg <= r_rx_shift_reg(FRAME_BITS-2 downto 0) & i_miso;
          else
            r_rx_shift_reg <= i_miso & r_rx_shift_reg(FRAME_BITS-1 downto 1);
          end if;

          -- Перевірка на кінець кадру
          if r_bits_received_counter = FRAME_BITS-1 then
            r_bits_received_counter <= 0;
            r_data_valid_pulse    <= '1'; -- Останній біт отримано, дані готові
          else
            r_bits_received_counter <= r_bits_received_counter + 1;
          end if;
        end if;
      end if;
    end if;
  end process RX_SAMPLE_LOGIC_PROC;
  
end architecture;