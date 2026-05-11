library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity memory_subsystem is
 port (
    clk           : in std_logic;
    --portovi ka IP-u
    reset         : in std_logic;
    start         : out std_logic;
    ready         : in std_logic;
    
    rows_out       : out std_logic_vector(5 downto 0);  -- Broj redova slike
    cols_out       : out std_logic_vector(5 downto 0);  -- Broj kolona slike
    lower_out      : out std_logic_vector(23 downto 0);  -- Donja granica boja (RGB)
    upper_out      : out std_logic_vector(23 downto 0);  -- Gornja granica boja (RGB)
    
--    bram1_en    : in std_logic;
--    bram1_we    : in std_logic;
--    bram1_addr  : in std_logic_vector(17 downto 0);
--    bram1_indata  : out std_logic_vector(23 downto 0);
--    bram1_outdata : in std_logic_vector(23 downto 0);
    
--    bram2_en  : in std_logic;
--    bram2_we  : in std_logic;
--    bram2_addr: in std_logic_vector(17 downto 0);
--    bram2_indata: out std_logic_vector(23 downto 0);
--    bram2_outdata: in std_logic_vector(23 downto 0);
       
    objects_count_in : in std_logic_vector(4 downto 0);  -- Broj detektovanih objekata
    
    --AXI interfejs
    reg_data_i  : in std_logic_vector(31 downto 0);
    
    --Komandni signali
    rows_wr_in       : in std_logic;
    cols_wr_in       : in std_logic;
    lower_wr_in      : in std_logic;
    upper_wr_in      : in std_logic;
    objects_wr_in    : in std_logic;
    
    rows_axi_out       : out std_logic_vector(5 downto 0); 
    cols_axi_out       : out std_logic_vector(5 downto 0);
    lower_axi_out      : out std_logic_vector(23 downto 0);
    upper_axi_out      : out std_logic_vector(23 downto 0);
    objects_axi_out    : out std_logic_vector(4 downto 0);
    
    --start
    cmd_wr_in    : in std_logic;
    cmd_axi_out  : out std_logic;
    
    --Ready
    status_axi_out : out std_logic
  );
end memory_subsystem;

architecture Behavioral of memory_subsystem is
signal rows_sig, cols_sig : std_logic_vector(5 downto 0);
signal  upper_sig, lower_sig : std_logic_vector(23 downto 0);
signal objects_count_sig : std_logic_vector(4 downto 0);
signal command_sig, status_sig : std_logic;

begin

--AXI strana
rows_axi_out <= rows_sig;
cols_axi_out <= cols_sig;
lower_axi_out <= lower_sig;
upper_axi_out <= upper_sig;
objects_axi_out <= objects_count_sig;
cmd_axi_out <= command_sig;
status_axi_out <= status_sig;

rows_out <= rows_sig;
cols_out <= cols_sig;
lower_out <= lower_sig;
upper_out <= upper_sig;
start <= command_sig;

--rows
process(clk)
begin
    if clk'event and clk = '1' then
         if reset = '1' then
            rows_sig <= (others => '0');
         elsif rows_wr_in = '1' then
            rows_sig <= reg_data_i(5 downto 0);
         end if;
     end if;
end process;

--cols
process(clk)
begin
    if clk'event and clk = '1' then
         if reset = '1' then
            cols_sig <= (others => '0');
         elsif cols_wr_in = '1' then
            cols_sig <= reg_data_i(5 downto 0);
         end if;
     end if;
end process;

--upper
process(clk)
begin
    if clk'event and clk = '1' then
         if reset = '1' then
            upper_sig <= (others => '0');
         elsif upper_wr_in = '1' then
            upper_sig <= reg_data_i(23 downto 0);
         end if;
     end if;
end process;

--lower
process(clk)
begin
    if clk'event and clk = '1' then
         if reset = '1' then
            lower_sig <= (others => '0');
         elsif lower_wr_in = '1' then
            lower_sig <= reg_data_i(23 downto 0);
         end if;
     end if;
end process;

--objects
process(clk)
begin
    if clk'event and clk = '1' then
         if reset = '0' then
            objects_count_sig <= (others => '0');
         else
            objects_count_sig <= objects_count_in;
         end if;
     end if;
end process;

--command
process(clk)
begin
    if clk'event and clk = '1' then
         if reset = '1' then
            command_sig <= '0';
         elsif cmd_wr_in = '1' then
            command_sig <= reg_data_i(0);
         end if;
     end if;
end process;

--status
process(clk)
begin
    if clk'event and clk = '1' then
         if reset = '0' then
            status_sig <= '0';
         else
            status_sig <= ready;
         end if;
     end if;
end process;

end Behavioral;
