library ieee;
use ieee.std_logic_1164.all;

-- Модуль передавача (MOSI)
-- Відповідає за завантаження паралельних даних та
-- послідовний зсув їх на лінію o_mosi
entity spi_tx_module is
  generic (
    FRAME_BITS : integer := 8;
    CPOL       : integer := 0;
    CPHA       : integer := 0;
    MSB_FIRST  : boolean := true
  );
  port (
    i_clk       : in  std_logic;                          -- Системний такт
    i_rst_n     : in  std_logic;                          -- Скид
    i_sclk      : in  std_logic;                          -- Рівень SCLK (від clkgen)
    i_edge      : in  std_logic;                          -- Імпульс на кожну зміну SCLK
    i_ss_n      : in  std_logic;                          -- Рівень SS_N (від clkgen)
    i_load      : in  std_logic;                          -- 1-тактний імпульс завантаження
    i_din       : in  std_logic_vector(FRAME_BITS-1 downto 0); -- Дані для завантаження
    o_mosi      : out std_logic;                          -- Вихід MOSI
    o_done_bits : out integer range 0 to FRAME_BITS       -- (не використовується)
  );
end entity;

architecture rtl of spi_tx_module is
  -- Внутрішній зсувний регістр
  signal r_tx_shift_reg    : std_logic_vector(FRAME_BITS-1 downto 0) := (others=>'0');
  -- Регістр для поточного вихідного біта
  signal r_mosi_out_bit    : std_logic := '0';
  -- Лічильник відправлених біт (для CPHA=1)
  signal r_bits_sent_counter : integer range 0 to FRAME_BITS := 0;

  -- Функція визначає, чи є поточний фронт SCLK "робочим" для ЗСУВУ даних.
  -- Згідно зі стандартом SPI, це фронт, ПРОТИЛЕЖНИЙ до того, 
  -- на якому відбувається читання (sample).
  function is_transmit_edge(cpol, cpha: integer; sclk_level: std_logic) return boolean is
  begin
    if (cpol=0 and cpha=0) then     -- Mode 0: Sample on Rising, Shift on Falling
      return (sclk_level='1');      -- Falling
    elsif (cpol=0 and cpha=1) then  -- Mode 1: Sample on Falling, Shift on Rising
      return (sclk_level='0');      -- Rising
    elsif (cpol=1 and cpha=0) then  -- Mode 2: Sample on Falling, Shift on Rising
      return (sclk_level='0');      -- Rising
    else                            -- Mode 3: Sample on Rising, Shift on Falling
      return (sclk_level='1');      -- Falling
    end if;
  end;
  
begin
  o_mosi      <= r_mosi_out_bit;
  o_done_bits <= r_bits_sent_counter;

  -- Логіка передавача
  TX_SHIFT_LOGIC_PROC: process(i_clk, i_rst_n)
  begin
    if i_rst_n='0' then
      r_mosi_out_bit    <= '0';
      r_tx_shift_reg    <= (others=>'0');
      r_bits_sent_counter <= 0;
    elsif rising_edge(i_clk) then
    
      -- Логіка скидання/завантаження (коли SS_N неактивний)
      if i_ss_n='1' then
        r_bits_sent_counter <= 0;
        
        -- Якщо SS_N='1' і прийшов 'load', завантажуємо дані
        if i_load='1' then
          r_tx_shift_reg <= i_din;
          
          -- Для CPHA=0, ми повинні виставити ПЕРШИЙ біт
          -- ще до першого такту SCLK (одразу при активації SS_N).
          -- Для CPHA=1, перший біт виставляється на першому 'shift edge'.
          if CPHA = 0 then
            if MSB_FIRST then
              r_mosi_out_bit <= i_din(FRAME_BITS-1);
            else
              r_mosi_out_bit <= i_din(0);
            end if;
          end if;
          
        end if;
      
      -- Логіка зсуву (коли SS_N активний)
      else
        -- Реагуємо тільки на зміну SCLK (сигнал 'i_edge')
        if i_edge='1' then
          -- Перевіряємо, чи це фронт для ЗСУВУ
          if is_transmit_edge(CPOL, CPHA, i_sclk) then
            if MSB_FIRST then
              r_mosi_out_bit <= r_tx_shift_reg(FRAME_BITS-2);
              r_tx_shift_reg <= r_tx_shift_reg(FRAME_BITS-2 downto 0) & '0';
            else
              r_mosi_out_bit <= r_tx_shift_reg(1);
              r_tx_shift_reg <= '0' & r_tx_shift_reg(FRAME_BITS-1 downto 1);
            end if;
          else
            -- Це фронт для ЧИТАННЯ (sample), просто рахуємо
            if r_bits_sent_counter < FRAME_BITS then
              r_bits_sent_counter <= r_bits_sent_counter + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process TX_SHIFT_LOGIC_PROC;
  
end architecture;