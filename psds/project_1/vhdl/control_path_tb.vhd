library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
use ieee.std_logic_textio.all;
use STD.textio.all;

use STD.TEXTIO.ALL;  -- For reading and writing text files

entity control_path_tb is
end control_path_tb;

architecture Behavioral of control_path_tb is

    -- Signals for simulation
    signal clk               : std_logic := '0';
    signal reset             : std_logic := '1';
    signal start             : std_logic := '0';
    signal rows_in           : std_logic_vector(5 downto 0);
    signal cols_in           : std_logic_vector(5 downto 0);
    signal lower_in          : std_logic_vector(23 downto 0); -- Lower RGB threshold (black)
    signal upper_in          : std_logic_vector(23 downto 0); -- Upper RGB threshold (white)
    signal mask_out          : std_logic_vector(255 downto 0);              -- Processed mask
    signal objects_count_out : std_logic_vector(4 downto 0);                     -- Object count
    
    signal bram1_en      : std_logic;
    signal bram1_we      : std_logic;
    signal bram1_addr    : std_logic_vector(11 downto 0);
    signal bram1_indata  : std_logic_vector(23 downto 0);
    signal bram1_outdata : std_logic_vector(23 downto 0);
    
    signal bram2_en      : std_logic;
    signal bram2_we      : std_logic;
    signal bram2_addr    : std_logic_vector(11 downto 0);
    signal bram2_indata  : std_logic_vector(23 downto 0);
    signal bram2_outdata : std_logic_vector(23 downto 0);
    
    signal en1_b   : std_logic;   
    signal we1_b   : std_logic;  
    signal addr1_b : std_logic_vector (11 downto 0);  
    signal din1_b  : std_logic_vector (23 downto 0); 
    signal dout1_b : std_logic_vector (23 downto 0);
    
    signal en2_b   : std_logic;   
    signal we2_b   : std_logic;  
    signal addr2_b : std_logic_vector (11 downto 0);  
    signal din2_b  : std_logic_vector (23 downto 0); 
    signal dout2_b : std_logic_vector (23 downto 0);

    type inputData is array (0 to 3720) of std_logic_vector(23 downto 0);
    signal inputDataT1 : inputData;
    signal inputDataT2 : inputData;

    -- File declarations for reading and writing
    file input_file  : text;

    component control_path is
        port (
    clk           : in std_logic;
    reset         : in std_logic;
    start         : in std_logic;
    
    rows_in       : in std_logic_vector(5 downto 0);  -- Broj redova slike
    cols_in       : in std_logic_vector(5 downto 0);  -- Broj kolona slike
    lower_in      : in std_logic_vector(23 downto 0);  -- Donja granica boja (RGB)
    upper_in      : in std_logic_vector(23 downto 0);  -- Gornja granica boja (RGB)
    
    bram1_en    : out std_logic;
    bram1_we    : out std_logic;
    bram1_addr  : out std_logic_vector(11 downto 0);
    bram1_indata  : in std_logic_vector(23 downto 0);
    bram1_outdata : out std_logic_vector(23 downto 0);
    
    bram2_en  : out std_logic;
    bram2_we  : out std_logic;
    bram2_addr: out std_logic_vector(11 downto 0);
    bram2_indata: in std_logic_vector(23 downto 0);
    bram2_outdata: out std_logic_vector(23 downto 0);
     
    objects_count_out : out std_logic_vector(4 downto 0)
  );
    end component;
    
  component dual_port_bram is
    generic (
    DATA_WIDTH : integer := 24;  
    ADDR_WIDTH : integer := 12    
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
    end component; 

begin


    -- Instantiate control_path component
    uut : control_path
        port map (
            clk               => clk,
            reset             => reset,
            start             => start,
            rows_in           => rows_in,
            cols_in           => cols_in,
            lower_in          => lower_in,
            upper_in          => upper_in,
            
            bram1_en          => bram1_en,  
            bram1_we          => bram1_we,
            bram1_addr        => bram1_addr,
            bram1_indata      => bram1_indata,
            bram1_outdata     => bram1_outdata,
            
            bram2_en          => bram2_en,
            bram2_we          =>  bram2_we, 
            bram2_addr        =>  bram2_addr,
            bram2_indata      => bram2_indata,
            bram2_outdata     => bram2_outdata,
              
            objects_count_out => objects_count_out
        );
        
     bram1: dual_port_bram
            port map(     
            clk    => clk,
            en_a   => bram1_en,
            we_a   => bram1_we,  
            addr_a => bram1_addr, 
            din_a  => bram1_outdata, 
            dout_a => bram1_indata,
        
            en_b    => en1_b,
            we_b    => we1_b,
            addr_b  => addr1_b,  
            din_b   => din1_b,
            dout_b  => dout1_b
           );
           
      bram2: dual_port_bram
            port map(     
            clk    => clk,
            en_a   => bram2_en,
            we_a   => bram2_we,  
            addr_a => bram2_addr, 
            din_a  => bram2_outdata, 
            dout_a => bram2_indata,
        
            en_b   => en2_b,
            we_b   => we2_b,
            addr_b => addr2_b,  
            din_b  => din2_b,
            dout_b => dout2_b
           );

    -- Clock generation process
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 10 ns;
            clk <= '1';
            wait for 10 ns;
        end loop;
    end process;

    load_image : process
        variable line_buffer : line;
        variable pixel_value : std_logic_vector(23 downto 0):=(others=>'0');
        variable index : integer :=0;
    begin
    
        file_open(input_file, "C:/Users/nikol/Downloads/psdsvivado/Charmander/slika.txt");
--        Read pixels and load into BRAM
        while not endfile(input_file) loop
            readline(input_file, line_buffer);
            read(line_buffer, pixel_value);
            inputDataT1(index) <= pixel_value;
            index := index + 1;
--            wait for 20 ns; -- Simulate writing
        end loop;
        file_close(input_file);
        wait;
    end process;

    -- Stimulus process to trigger simulation and extract results
stimulus : process
    variable addr : integer := 0;
    variable pixel_value : integer;
begin
    reset <= '1';
    wait for 100 ns;
    reset <= '0';
    wait for 100 ns;
    we2_b <= '1';
    en2_b <= '1';
    we1_b <= '1';
    en1_b <= '1';
    wait until falling_edge(clk);
        for i in 0 to 3720 loop
            addr1_b <= std_logic_vector(to_unsigned(i,addr1_b'length));
            din1_b <= inputDataT1(i);
            wait until falling_edge(clk);
        end loop;
        wait for 100 ns;
        we1_b <= '0';
        en1_b <= '0';
        we2_b <= '0';
        en2_b <= '0';
        start <= '1';
    cols_in <= std_logic_vector(to_unsigned(61, cols_in'length));
    rows_in <= std_logic_vector(to_unsigned(61, rows_in'length));
    
----    Charmander color values
    lower_in <= "101101000101101000110010";
    upper_in <= "111111111000001001000110";
    
--    Bulbasaur color values - change file direction of txt input file for Bulbasaur
--    lower_in <= "011001001000011101010000";
--    upper_in <= "100001111100100010001100";

    wait for 100 ns;
    start <= '0';
    wait for 10000 ns;
    wait;
    end process;

end;