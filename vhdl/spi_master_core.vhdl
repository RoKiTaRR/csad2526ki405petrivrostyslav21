library ieee;
use ieee.std_logic_1164.all;

-- Головний модуль SPI Master, який об'єднує генератор такту, 
-- передавач та приймач в один логічний пристрій.
entity spi_master_core is
  generic (
    -- Системна тактова частота (напр. 50 МГц)
    G_SYS_CLK_HZ : integer := 50_000_000;
    -- Цільова частота SPI (напр. 1 МГц)
    G_SCLK_HZ    : integer := 1_000_000;
    -- Кількість біт у кадрі
    G_FRAME_BITS : integer := 8;
    -- Полярність SCLK (0 = Idle Low, 1 = Idle High)
    G_CPOL       : integer := 0;
    -- Фаза SCLK (0 = Sample on 1st edge, 1 = Sample on 2nd edge)
    G_CPHA       : integer := 0;
    -- Порядок біт (true = MSB first, false = LSB first)
    G_MSB_FIRST  : boolean := true
  );
  port (
    -- === Системні сигнали ===
    i_clk     : in  std_logic; -- Системний такт
    i_rst_n   : in  std_logic; -- Асинхронний скид (активний '0')

    -- === Інтерфейс користувача (CPU/FIFO) ===
    i_tx_data  : in  std_logic_vector(G_FRAME_BITS-1 downto 0); -- Дані для відправки
    i_tx_valid : in  std_logic; -- 1-тактний імпульс "почати відправку"
    o_busy     : out std_logic; -- '1' = транзакція активна
    o_rx_data  : out std_logic_vector(G_FRAME_BITS-1 downto 0); -- Отримані дані
    o_rx_valid : out std_logic; -- 1-тактний імпульс "дані отримано"

    -- === Фізичні лінії SPI ===
    o_sclk     : out std_logic; -- SPI Clock
    o_mosi     : out std_logic; -- Master Out Slave In
    i_miso     : in  std_logic; -- Master In Slave Out
    o_ss_n     : out std_logic  -- Slave Select (активний '0')
  );
end entity;

architecture rtl of spi_master_core is
  -- Внутрішні сигнали для зв'язку між модулями
  signal int_sclk        : std_logic;
  signal int_ss_n        : std_logic;
  signal w_clk_edge      : std_logic; -- Імпульс на кожну зміну SCLK
  signal r_is_busy       : std_logic; -- Внутрішній сигнал 'busy'
  
  -- Сигнали для керування
  signal w_start_tx_pulse : std_logic; -- Внутрішній старт транзакції
  signal w_rx_data_valid  : std_logic; -- Внутрішній 'rx_valid'
  signal w_rx_shift_reg   : std_logic_vector(G_FRAME_BITS-1 downto 0);
  signal int_mosi         : std_logic; -- Внутрішній MOSI
  
begin
  -- Призначення виходів
  o_sclk     <= int_sclk;
  o_ss_n     <= int_ss_n;
  o_mosi     <= int_mosi;
  o_busy     <= r_is_busy;
  o_rx_data  <= w_rx_shift_reg;
  o_rx_valid <= w_rx_data_valid;

  -- === 1. Генератор такту та SS ===
  i_spi_clkgen: entity work.spi_clk_generator
    generic map (
      SYS_CLK_HZ => G_SYS_CLK_HZ,
      SCLK_HZ    => G_SCLK_HZ,
      CPOL       => G_CPOL
    )
    port map (
      i_clk    => i_clk,
      i_rst_n  => i_rst_n,
      i_start  => w_start_tx_pulse, -- Запускається по імпульсу
      i_bits   => G_FRAME_BITS,
      o_active => r_is_busy,        -- Вихід 'busy'
      o_sclk   => int_sclk,
      o_edge   => w_clk_edge,
      o_ss_n   => int_ss_n
    );

  -- === 2. Передавач (MOSI) ===
  i_spi_transmitter: entity work.spi_tx_module
    generic map (
      FRAME_BITS => G_FRAME_BITS,
      CPOL       => G_CPOL,
      CPHA       => G_CPHA,
      MSB_FIRST  => G_MSB_FIRST
    )
    port map (
      i_clk       => i_clk,
      i_rst_n     => i_rst_n,
      i_sclk      => int_sclk,    -- Використовуємо внутрішній SCLK
      i_edge      => w_clk_edge,
      i_ss_n      => int_ss_n,
      i_load      => w_start_tx_pulse, -- Завантажуємо дані по тому ж імпульсу
      i_din       => i_tx_data,
      o_mosi      => int_mosi,
      o_done_bits => open
    );

  -- === 3. Приймач (MISO) ===
  i_spi_receiver: entity work.spi_rx_module
    generic map (
      FRAME_BITS => G_FRAME_BITS,
      CPOL       => G_CPOL,
      CPHA       => G_CPHA,
      MSB_FIRST  => G_MSB_FIRST
    )
    port map (
      i_clk    => i_clk,
      i_rst_n  => i_rst_n,
      i_sclk   => int_sclk,    -- Використовуємо внутрішній SCLK
      i_edge   => w_clk_edge,
      i_ss_n   => int_ss_n,
      i_miso   => i_miso,
      o_dout   => w_rx_shift_reg,
      o_count  => open,
      o_valid  => w_rx_data_valid
    );

  -- === 4. Контролер кадру ===
  -- Цей процес генерує однотактний імпульс 'w_start_tx_pulse',
  -- коли модуль не зайнятий (r_is_busy = '0') і користувач 
  -- дає команду (i_tx_valid = '1').
  MASTER_FSM_PROC: process(i_clk, i_rst_n)
  begin
    if i_rst_n = '0' then
      w_start_tx_pulse <= '0';
    elsif rising_edge(i_clk) then
      -- Скидаємо імпульс за замовчуванням
      w_start_tx_pulse <= '0';
      
      -- Генеруємо імпульс, якщо вільні і є запит
      if (r_is_busy = '0' and i_tx_valid = '1') then
        w_start_tx_pulse <= '1';
      end if;
    end if;
  end process MASTER_FSM_PROC;
  
end architecture;