library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Цей модуль генерує сигнали SCLK та SS_N
-- згідно з налаштуваннями CPOL та частоти.
entity spi_clk_generator is
  generic (
    SYS_CLK_HZ : integer := 50_000_000;
    SCLK_HZ    : integer := 1_000_000;
    CPOL       : integer := 0              -- 0 або 1 (рівень SCLK у простої)
  );
  port (
    i_clk    : in  std_logic;              -- Системний такт
    i_rst_n  : in  std_logic;              -- Скид
    i_start  : in  std_logic;              -- 1-тактний імпульс запуску
    i_bits   : in  integer range 1 to 32;  -- Довжина кадру (біти)
    o_active : out std_logic;              -- '1' під час транзакції (сигнал busy)
    o_sclk   : out std_logic;              -- Вихід SCLK
    o_edge   : out std_logic;              -- 1-тактний імпульс на кожну зміну SCLK
    o_ss_n   : out std_logic               -- Вихід Slave Select (активний '0')
  );
end entity;

architecture rtl of spi_clk_generator is
  -- Допоміжна функція для визначення максимуму
  function max_integer(a, b : integer) return integer is
  begin
    if a > b then return a; else return b; end if;
  end function;

  -- Розрахунок дільника: SCLK_HZ = SYS_CLK_HZ / (2 * DIV_C)
  constant C_DIVIDE_VAL : integer := integer(real(SYS_CLK_HZ) / real(2*SCLK_HZ));
  constant C_DIVIDER    : integer := max_integer(C_DIVIDE_VAL, 1); -- Мінімум 1

  -- Сигнал, що визначає рівень SCLK у простої
  signal w_sclk_idle_level : std_logic := '0';
  
  -- Регістри для вихідних сигналів
  signal r_sclk_out          : std_logic := '0';
  signal r_sclk_edge_pulse : std_logic := '0';
  signal r_ss_n_out          : std_logic := '1';
  signal r_is_active         : std_logic := '0';

  -- Внутрішні лічильники
  signal r_sys_clk_divider     : integer range 0 to C_DIVIDER-1 := 0;
  signal r_half_period_counter : integer := 0; -- Лічильник півперіодів SCLK

begin
  -- Визначаємо рівень SCLK у простої на основі CPOL
  w_sclk_idle_level <= '1' when CPOL = 1 else '0';

  -- Призначення виходів
  o_sclk   <= r_sclk_out;
  o_edge   <= r_sclk_edge_pulse;
  o_ss_n   <= r_ss_n_out;
  o_active <= r_is_active;

  -- Основний процес-генератор
  CLK_GENERATOR_PROC: process(i_clk, i_rst_n)
  begin
    if i_rst_n = '0' then
      r_sclk_out          <= w_sclk_idle_level;
      r_sclk_edge_pulse   <= '0';
      r_sys_clk_divider   <= 0;
      r_half_period_counter <= 0;
      r_is_active         <= '0';
      r_ss_n_out          <= '1';
    elsif rising_edge(i_clk) then
      -- Скидаємо імпульс 'edge' кожного такту
      r_sclk_edge_pulse <= '0';

      -- === FSM State: IDLE ===
      -- Очікування команди на старт
      if (r_is_active = '0' and i_start = '1') then
        r_is_active         <= '1';
        r_ss_n_out          <= '0'; -- Активуємо Slave Select
        r_half_period_counter <= 0;
        r_sclk_out          <= w_sclk_idle_level;
        r_sys_clk_divider   <= 0;
      end if;

      -- === FSM State: ACTIVE ===
      -- Генерація SCLK, поки транзакція активна
      if r_is_active = '1' then
        if r_sys_clk_divider = C_DIVIDER - 1 then
          -- Час інвертувати SCLK
          r_sys_clk_divider   <= 0;
          r_sclk_out          <= not r_sclk_out;
          r_sclk_edge_pulse   <= '1'; -- Генеруємо імпульс 'edge'
          r_half_period_counter <= r_half_period_counter + 1;

          -- Перевірка на завершення кадру
          -- Нам потрібно 2*N_bits півперіодів
          if r_half_period_counter = (2*i_bits - 1) then
            -- Це був останній півперіод, завершуємо транзакцію
            r_is_active <= '0';
            r_ss_n_out  <= '1'; -- Деактивуємо Slave Select
            r_sclk_out  <= w_sclk_idle_level; -- Повертаємо SCLK у простій
          end if;
        else
          -- Просто рахуємо такти системного годинника
          r_sys_clk_divider <= r_sys_clk_divider + 1;
        end if;
      end if;
    end if;
  end process CLK_GENERATOR_PROC;
  
end architecture;