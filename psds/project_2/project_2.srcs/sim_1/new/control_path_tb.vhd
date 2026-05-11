library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- Ovo je potrebno za to_unsigned
use STD.TEXTIO.ALL;  -- Potrebno za ?itanje tekstualnih fajlova

entity control_path_tb is
end control_path_tb;

architecture Behavioral of control_path_tb is

    -- Signali za simulaciju
    signal clk           : std_logic := '0';
    signal reset         : std_logic := '1';
    signal start         : std_logic := '0';
    signal rows          : unsigned(8 downto 0) := to_unsigned(400, 9);  -- 400 redova
    signal cols          : unsigned(8 downto 0) := to_unsigned(200, 9);  -- 200 kolona
    signal channels      : unsigned(2 downto 0) := "011";         -- 3 kanala (RGB)
    signal lower         : std_logic_vector(23 downto 0) := (others => '0');
    signal upper         : std_logic_vector(23 downto 0) := (others => '1');
    signal pixel_mem     : std_logic_vector(255 downto 0);        -- Memorija slike (256 bita po liniji)
    signal mask_mem      : std_logic_vector(255 downto 0);        -- Memorija maske
    signal mask_next     : std_logic_vector(255 downto 0);        -- Obradjena maska
    signal objects_count : integer range 0 to 10000;              -- Broj objekata

    component control_path
    port (
        clk           : in std_logic;
        reset         : in std_logic;
        start         : in std_logic;
        rows          : in unsigned(8 downto 0);
        cols          : in unsigned(8 downto 0);
        channels      : in unsigned(2 downto 0);
        lower         : in std_logic_vector(23 downto 0);
        upper         : in std_logic_vector(23 downto 0);
        pixel_mem     : in std_logic_vector(255 downto 0);
        mask_mem      : in std_logic_vector(255 downto 0);
        mask_next     : out std_logic_vector(255 downto 0);
        objects_count : out integer range 0 to 10000
    );
    end component;

    -- U?itavanje slike iz fajla
    file image_file : text open read_mode is "C:/Users/nikol/Downloads/image_data.txt"; -- Full path to the file


begin

    -- Clock signal generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for 10 ns;
            clk <= '1';
            wait for 10 ns;
        end loop;
    end process;

    -- U?itaj piksele iz fajla u pixel_mem
    load_pixels : process
        variable line_in : line;
        variable pixel_val : std_logic_vector(23 downto 0);  -- 24-bitni RGB piksel
        variable pixel_index : integer := 0;
        variable pixel_str : string(1 to 24);  -- 24-bit strings for RGB pixels
    begin
        while not endfile(image_file) loop
            readline(image_file, line_in);
            read(line_in, pixel_str);  -- ?itanje kao string
            for i in 1 to 24 loop
                if pixel_str(i) = '0' then
                    pixel_val(24 - i) := '0';  -- Ako je karakter '0'
                else
                    pixel_val(24 - i) := '1';  -- Ako je karakter '1'
                end if;
            end loop;

            pixel_mem(pixel_index * 24 + 23 downto pixel_index * 24) <= pixel_val;  -- Smeštanje piksela u memoriju
            pixel_index := pixel_index + 1;

            if pixel_index = 10 then  -- This condition ensures pixel_mem does not exceed 255 bits (adjust if needed)
                exit;
            end if;
        end loop;
        wait;
    end process;

    -- DUT instantiation
    uut: control_path
    port map (
        clk           => clk,
        reset         => reset,
        start         => start,
        rows          => rows,
        cols          => cols,
        channels      => channels,
        lower         => lower,
        upper         => upper,
        pixel_mem     => pixel_mem,
        mask_mem      => mask_mem,
        mask_next     => mask_next,
        objects_count => objects_count
    );

    -- Stimuli proces
    process
    begin
        -- Reset system
        reset <= '1';
        wait for 20 ns;
        reset <= '0';
        
        -- Start image processing
        start <= '1';
        
        -- Wait for the processing to finish
        wait for 1000 ns;
        start <= '0';

        -- Finish the simulation
        wait;
    end process;
end Behavioral;
