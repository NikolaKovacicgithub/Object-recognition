library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

entity dual_port_bram is
  generic (
    DATA_WIDTH : integer := 24;   -- Width of the data bus (256 bits)
    ADDR_WIDTH : integer := 12     -- Address width (supports 8192 locations, more than enough for 4500)
  );
  port (
    clk       : in std_logic;                   -- Clock signal
    en_a      : in std_logic;                   -- Enable signal for Port A
    we_a      : in std_logic;                   -- Write Enable for Port A
    addr_a    : in std_logic_vector(ADDR_WIDTH-1 downto 0); -- Address for Port A
    din_a     : in std_logic_vector(DATA_WIDTH-1 downto 0); -- Data input for Port A
    dout_a    : out std_logic_vector(DATA_WIDTH-1 downto 0); -- Data output for Port A

    en_b      : in std_logic;                   -- Enable signal for Port B
    we_b      : in std_logic;                   -- Write Enable for Port B
    addr_b    : in std_logic_vector(ADDR_WIDTH-1 downto 0); -- Address for Port B
    din_b     : in std_logic_vector(DATA_WIDTH-1 downto 0); -- Data input for Port B
    dout_b    : out std_logic_vector(DATA_WIDTH-1 downto 0) -- Data output for Port B
  );
end dual_port_bram;

architecture Behavioral of dual_port_bram is
  -- Memory array declaration (2^ADDR_WIDTH locations with DATA_WIDTH bits in each location)
  type ram_type is array (0 to 3720) of std_logic_vector(23 downto 0);
  shared variable ram : ram_type;

begin
  -- Port A (Supports independent read/write operations)
  process(clk)
    begin
        if clk'event and clk = '1' then
            if en_a = '1' then
            dout_a <= ram(conv_integer(addr_a));
                if we_a = '1' then
                ram(conv_integer(addr_a)) := din_a;
                end if;
            end if;
        end if;
    end process;
    
    process(clk)
    begin
        if clk'event and clk = '1' then
            if en_b = '1' then
            dout_b <= ram(conv_integer(addr_b));
                if we_b = '1' then
                ram(conv_integer(addr_b)) := din_b;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
