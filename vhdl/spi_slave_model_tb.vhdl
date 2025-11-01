library ieee;
use ieee.std_logic_1164.all;

-- Це поведінкова модель SPI Slave пристрою.
-- Вона не синтезується, а використовується ТІЛЬКИ у тестбенчі.
-- Її задача: приймати дані з MOSI та одночасно 
-- відправляти фіксовану відповідь (RESP_BYTE) на MISO.
entity spi_slave_model_tb is
  generic (
    FRAME_BITS : integer := 8;
    CPOL       : integer := 0;
    CPHA       : integer := 0;
    MSB_FIRST  : boolean := true;
    -- Відповідь, яку slave повертає (має бути 8 біт для цієї моделі)
    RESP_BYTE  : std_logic_vector(7 downto 0) := x"A5"
  );
  port (
    i_sclk : in  std_logic;
    i_ss_n : in  std_logic;
    i_mosi : in  std_logic;
    o_miso : out std_logic
  );
end entity;

architecture beh of spi_slave_model_tb is
  -- Регістри для зсуву (тільки 8 біт!)
  signal r_slave_tx_reg : std_logic_vector(7 downto 0) := RESP_BYTE;
  signal r_slave_rx_reg : std_logic_vector(7 downto 0) := (others=>'0');

  -- Функція визначає, чи треба читати/писати на RISING edge
  function check_sample_edge(cpol, cpha: integer) return boolean is
  begin
    if (cpol=0 and cpha=0) then return true;  end if; -- Mode 0
    if (cpol=0 and cpha=1) then return false; end if; -- Mode 1
    if (cpol=1 and cpha=0) then return false; end if; -- Mode 2
    return true; -- Mode 3
  end;
  
begin
  -- Цей процес моделює логіку slave, він чутливий до SCLK.
  -- УВАГА: Це НЕ синхронний процес до системного 'clk',
  -- а поведінкова модель, що реагує на 'sclk' від master-а.
  SLAVE_LOGIC_PROC: process(i_sclk, i_ss_n)
  begin
    if i_ss_n = '1' then
      -- Скидання логіки, коли не обрані
      r_slave_tx_reg <= RESP_BYTE;
      r_slave_rx_reg <= (others=>'0');
      o_miso         <= '0'; -- Або 'Z'
    else
      -- === Логіка для Mode 0 та 3 (Sample on Rising) ===
      if rising_edge(i_sclk) then
        if check_sample_edge(CPOL, CPHA) then
          -- Читаємо MISO
          r_slave_rx_reg <= r_slave_rx_reg(6 downto 0) & i_mosi;
        else
          -- Виставляємо MOSI
          o_miso         <= r_slave_tx_reg(7);
          r_slave_tx_reg <= r_slave_tx_reg(6 downto 0) & '0';
        end if;
      
      -- === Логіка для Mode 1 та 2 (Sample on Falling) ===
      elsif falling_edge(i_sclk) then
        if not check_sample_edge(CPOL, CPHA) then
          -- Читаємо MISO
          r_slave_rx_reg <= r_slave_rx_reg(6 downto 0) & i_mosi;
        else
          -- Виставляємо MOSI
          o_miso         <= r_slave_tx_reg(7);
          r_slave_tx_reg <= r_slave_tx_reg(6 downto 0) & '0';
        end if;
      end if;
    end if;
  end process SLAVE_LOGIC_PROC;
  
end architecture;