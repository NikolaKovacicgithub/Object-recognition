library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity myip_v1_0 is
	generic (
		-- Users to add parameters here
        DATA_WIDTH : integer := 24;
        ADDR_WIDTH : integer := 12;
		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 5
	);
	port (
		-- Users to add ports here
        bram1_data_en_in      : in std_logic;
        bram1_data_wr_in      : in std_logic;
        bram1_addr_in         : in std_logic_vector(11 downto 0);
        bram1_datain          : in std_logic_vector(23 downto 0);
        bram1_dataout         : out std_logic_vector(23 downto 0);
        
--        bram2_data_en_in      : in std_logic;
--        bram2_data_wr_in      : in std_logic;
--        bram2_addr_in         : in std_logic_vector(11 downto 0);
--        bram2_datain          : in std_logic_vector(23 downto 0);
--        bram2_dataout         : out std_logic_vector(23 downto 0);
		-- User ports ends
		-- Do not modify the ports beyond this line

		-- Ports of Axi Slave Bus Interface S00_AXI
		s00_axi_aclk	: in std_logic;
		s00_axi_aresetn	: in std_logic;
		s00_axi_awaddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_awprot	: in std_logic_vector(2 downto 0);
		s00_axi_awvalid	: in std_logic;
		s00_axi_awready	: out std_logic;
		s00_axi_wdata	: in std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_wstrb	: in std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		s00_axi_wvalid	: in std_logic;
		s00_axi_wready	: out std_logic;
		s00_axi_bresp	: out std_logic_vector(1 downto 0);
		s00_axi_bvalid	: out std_logic;
		s00_axi_bready	: in std_logic;
		s00_axi_araddr	: in std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		s00_axi_arprot	: in std_logic_vector(2 downto 0);
		s00_axi_arvalid	: in std_logic;
		s00_axi_arready	: out std_logic;
		s00_axi_rdata	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		s00_axi_rresp	: out std_logic_vector(1 downto 0);
		s00_axi_rvalid	: out std_logic;
		s00_axi_rready	: in std_logic
	);
end myip_v1_0;

architecture arch_imp of myip_v1_0 is

signal reset_s      : std_logic;
signal reg_data_s   : std_logic_vector (31 downto 0);
signal rows_wr_s    : std_logic; 
signal cols_wr_s    : std_logic; 
signal lower_wr_s   : std_logic;
signal upper_wr_s   : std_logic;
signal objects_wr_s : std_logic;
signal cmd_wr_s     : std_logic;
signal start_s      : std_logic;
signal ready_s      : std_logic;

signal rows_axi_s    : std_logic_vector(5 downto 0); 
signal cols_axi_s    : std_logic_vector(5 downto 0); 
signal lower_axi_s   : std_logic_vector(23 downto 0);
signal upper_axi_s   : std_logic_vector(23 downto 0);
signal objects_axi_s : std_logic_vector(4 downto 0);
signal cmd_axi_s     : std_logic; 
signal status_axi_s  : std_logic;

signal rows_out_s    : std_logic_vector(5 downto 0);
signal cols_out_s    : std_logic_vector(5 downto 0);
signal lower_out_s    : std_logic_vector(23 downto 0);
signal upper_out_s    : std_logic_vector(23 downto 0);
signal objects_count_s : std_logic_vector(4 downto 0);

signal bram1_en_s1   : std_logic;
signal bram1_we_s1   : std_logic;
signal bram1_addr_s1 : std_logic_vector(ADDR_WIDTH-1 downto 0);
signal bram1_din1    : std_logic_vector(DATA_WIDTH-1 downto 0);
signal bram1_dout1   : std_logic_vector(DATA_WIDTH-1 downto 0);

signal bram1_en_s2   : std_logic;
signal bram1_we_s2   : std_logic;
signal bram1_addr_s2 : std_logic_vector(ADDR_WIDTH-1 downto 0);
signal bram1_din2    : std_logic_vector(DATA_WIDTH-1 downto 0);
signal bram1_dout2   : std_logic_vector(DATA_WIDTH-1 downto 0);

signal bram2_en_s1   : std_logic;
signal bram2_we_s1   : std_logic;
signal bram2_addr_s1 : std_logic_vector(ADDR_WIDTH-1 downto 0);
signal bram2_din1    : std_logic_vector(DATA_WIDTH-1 downto 0);
signal bram2_dout1   : std_logic_vector(DATA_WIDTH-1 downto 0);

signal bram2_en_s2   : std_logic;
signal bram2_we_s2   : std_logic;
signal bram2_addr_s2 : std_logic_vector(ADDR_WIDTH-1 downto 0);
signal bram2_din2    : std_logic_vector(DATA_WIDTH-1 downto 0);
signal bram2_dout2   : std_logic_vector(DATA_WIDTH-1 downto 0);

signal dout_b_s : std_logic_vector(23 downto 0);

	-- component declaration
	component myip_v1_0_S00_AXI is
		generic (
		
		DATA_WIDTH : integer := 24;   -- Width of the data bus (256 bits)
        ADDR_WIDTH : integer := 12;
		
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		C_S_AXI_ADDR_WIDTH	: integer	:= 5
		);
		port (
		
		reg_data_o        : out std_logic_vector(31 downto 0);
		rows_wr_out       : out std_logic;
        cols_wr_out       : out std_logic;
        lower_wr_out      : out std_logic;
        upper_wr_out      : out std_logic;
        objects_wr_out    : out std_logic;
        cmd_wr_out        : out std_logic;
        
        rows_axi_in       : in std_logic_vector(5 downto 0); 
        cols_axi_in       : in std_logic_vector(5 downto 0);
        lower_axi_in      : in std_logic_vector(23 downto 0);
        upper_axi_in      : in std_logic_vector(23 downto 0);
        objects_axi_in    : in std_logic_vector(4 downto 0);
        cmd_axi_in        : in std_logic;
        status_axi_in     : in std_logic;
		
		S_AXI_ACLK	: in std_logic;
		S_AXI_ARESETN	: in std_logic;
		S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
		S_AXI_AWVALID	: in std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in std_logic;
		S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
		S_AXI_ARVALID	: in std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in std_logic
		);
	end component myip_v1_0_S00_AXI;

begin

-- Instantiation of Axi Bus Interface S00_AXI
myip_v1_0_S00_AXI_inst : myip_v1_0_S00_AXI
	generic map (
	
	    DATA_WIDTH => DATA_WIDTH,
	    ADDR_WIDTH => ADDR_WIDTH,
		C_S_AXI_DATA_WIDTH	=> C_S00_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH	=> C_S00_AXI_ADDR_WIDTH
	)
	port map (
	    
	    reg_data_o => reg_data_s,
	    rows_wr_out => rows_wr_s,
	    cols_wr_out => cols_wr_s,
	    lower_wr_out => lower_wr_s,
	    upper_wr_out => upper_wr_s,
	    objects_wr_out => objects_wr_s,
	    cmd_wr_out => cmd_wr_s,
	    
	    rows_axi_in => rows_axi_s,
	    cols_axi_in => cols_axi_s,
	    lower_axi_in => lower_axi_s,
	    upper_axi_in => upper_axi_s,
	    objects_axi_in => objects_axi_s,
	    cmd_axi_in => cmd_axi_s,
	    status_axi_in => status_axi_s,
	    	    	   
		S_AXI_ACLK	=> s00_axi_aclk,
		S_AXI_ARESETN	=> s00_axi_aresetn,
		S_AXI_AWADDR	=> s00_axi_awaddr,
		S_AXI_AWPROT	=> s00_axi_awprot,
		S_AXI_AWVALID	=> s00_axi_awvalid,
		S_AXI_AWREADY	=> s00_axi_awready,
		S_AXI_WDATA	=> s00_axi_wdata,
		S_AXI_WSTRB	=> s00_axi_wstrb,
		S_AXI_WVALID	=> s00_axi_wvalid,
		S_AXI_WREADY	=> s00_axi_wready,
		S_AXI_BRESP	=> s00_axi_bresp,
		S_AXI_BVALID	=> s00_axi_bvalid,
		S_AXI_BREADY	=> s00_axi_bready,
		S_AXI_ARADDR	=> s00_axi_araddr,
		S_AXI_ARPROT	=> s00_axi_arprot,
		S_AXI_ARVALID	=> s00_axi_arvalid,
		S_AXI_ARREADY	=> s00_axi_arready,
		S_AXI_RDATA	=> s00_axi_rdata,
		S_AXI_RRESP	=> s00_axi_rresp,
		S_AXI_RVALID	=> s00_axi_rvalid,
		S_AXI_RREADY	=> s00_axi_rready
	);

	-- Add user logic here
    reset_s <= not s00_axi_aresetn;
    
     mem_subsystem: entity work.memory_subsystem(Behavioral)
        port map (
            clk           => s00_axi_aclk, 
            reset         => reset_s,
            start         => start_s,
            ready         => ready_s,
            
            rows_out         => rows_out_s,
            cols_out         => cols_out_s,
            lower_out        => lower_out_s,
            upper_out        => upper_out_s,
            objects_count_in => objects_count_s,
            
--            bram1_en         => bram1_en_s2,
--            bram1_we         => bram1_we_s2,
--            bram1_addr       => bram1_addr_s2,
--            bram1_indata     => bram1_din2,
--            bram1_outdata    => bram1_dout2,
            
--            bram2_en         => bram2_en_s2,
--            bram2_we         => bram2_we_s2,
--            bram2_addr       => bram2_addr_s2,
--            bram2_indata     => bram2_din2,
--            bram2_outdata    => bram2_dout2,
            
            reg_data_i    => reg_data_s,
            rows_wr_in    => rows_wr_s,
            cols_wr_in    => cols_wr_s,
            lower_wr_in   => lower_wr_s,
            upper_wr_in   => upper_wr_s,
            objects_wr_in => objects_wr_s,
            
            rows_axi_out    => rows_axi_s,
            cols_axi_out    => cols_axi_s,
            lower_axi_out   => lower_axi_s,
            upper_axi_out   => upper_axi_s,
            objects_axi_out => objects_axi_s,
            
            cmd_wr_in       => cmd_wr_s,
            cmd_axi_out     => cmd_axi_s,
            status_axi_out  => status_axi_s                   
        );
        
     ip_module: entity work.control_path
       port map(
        clk               => s00_axi_aclk,
        reset             => reset_s,
        start             => start_s,
        ready             => ready_s,
        
        rows_in           => rows_out_s,
        cols_in           => cols_out_s,
        lower_in          => lower_out_s,
        upper_in          => upper_out_s,
        
        bram1_en          => bram1_en_s1,
        bram1_we          => bram1_we_s1,  
        bram1_addr        => bram1_addr_s1,
        bram1_indata      => bram1_din1,
        bram1_outdata     => bram1_dout1,
        
        bram2_en          => bram2_en_s1,
        bram2_we          => bram2_we_s1,
        bram2_addr        => bram2_addr_s1,
        bram2_indata      => bram2_din1,
        bram2_outdata     => bram2_dout1,
           
        objects_count_out => objects_count_s       );
       
       bram1: entity work.dual_port_bram
       generic map(
        DATA_WIDTH => DATA_WIDTH,
        ADDR_WIDTH => ADDR_WIDTH   
       )
        port map(       
        clk      => s00_axi_aclk,
        en_a     => bram1_en_s1,
        we_a     => bram1_we_s1,
        addr_a   => bram1_addr_s1,
        din_a    => bram1_din1,
        dout_a   => bram1_dout1,
    
        en_b     => bram1_data_en_in,
        we_b     => bram1_data_wr_in,
        addr_b   => bram1_addr_in,
        din_b    => bram1_datain,
        dout_b   => bram1_dataout 
        );
          
       bram2: entity work.dual_port_bram
       generic map(
        DATA_WIDTH => DATA_WIDTH,
        ADDR_WIDTH => ADDR_WIDTH   
       )
        port map(
        clk     => s00_axi_aclk,
        en_a    => bram2_en_s1,
        we_a    => bram2_we_s1,
        addr_a  => bram2_addr_s1,
        din_a   => bram2_din1,
        dout_a  => bram2_dout1,
    
        en_b     => '0',
        we_b     => '0',
        addr_b   => (others=>'0'),
        din_b    => (others=>'0'),
        dout_b   => dout_b_s 
        );

       
	-- User logic ends

end arch_imp;
