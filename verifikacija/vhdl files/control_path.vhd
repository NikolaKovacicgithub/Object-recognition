library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_path is
  port (
    clk           : in std_logic;
    reset         : in std_logic;
    start         : in std_logic;
    ready         : out std_logic;
    
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
end control_path;

architecture Behavioral of control_path is
  -- Tipovi stanja
  type state_type is (IDLE, CHECK_MINX, CHECK_MAXX, CHECK_MINY, CHECK_MAXY, CHECK_PIXEL2, TEMP12, BRAM_WRITE2, TEMP11, BRAM_READ_IMAGE7, INC2_X, INC2_Y, BRAM_READ_IMAGE6, TEMP10, TEMP9, BRAM_WRITE_PIXEL, BRAM_CHECK, CHECK, CHECK_PIXEL1, IJ1, TEMP8, BRAM_READ_IMAGE4, BRAM_WRITE1, TEMP6, TEMP7, INC1_X, INC1_Y, BRAM_READ_IMAGE5, IJ, TEMP, TEMP1, TEMP2, TEMP3, TEMP4, TEMP5, BRAM_READ_IMAGE1, BRAM_READ_IMAGE2, BRAM_READ_IMAGE3, BRAM_WRITE, INC_X, INC_Y, WRITE_TO_BRAM_MASK1, WRITE_TO_BRAM_MASK2, MASK_OUTER, MASK_INNER, CHECK_PIXEL, DILATION_OUTER, DILATION_INNER, MASKA, DILATION_I, DILATION_J, DILATION_END, XPLUS, PIXEL_OUTER, PIXEL_INNER, X1PLUS, TEMP_I, WHITE, TEMP_J, NEWW, IPLUS, CONTOUR_OUTER, CONTOUR_INNER, FIND_CONTOURS_WHILE, VISITE, END_CONTOUR, X2PLUS, AREA_CHECK, PIXEL_CHECK, FIND_CONTOURS_I, RECTANGLE_LOOP, RECTANGLE_HORIZONTAL_LOOP, RECTANGLE_VERTICAL, RECTANGLE_TOP, COLOR_VERTICAL);
  signal current_state, next_state: state_type;

  -- Signali za pracenje trenutnih koordinata piksela
signal x_reg, y_reg: std_logic_vector(5 downto 0);
signal x_next, y_next: std_logic_vector(5 downto 0);
signal i_reg, j_reg: std_logic_vector(3 downto 0);
signal i_next, j_next: std_logic_vector(3 downto 0);
signal newY_reg, newX_reg: std_logic_vector(5 downto 0);
signal newY_next, newX_next: std_logic_vector(5 downto 0);

  -- Promenljive za pracenje kontura
signal area_reg, area_next: integer := 0;              -- Povr ina konture
signal min_x_reg, max_x_reg: integer;       -- Minimalne i maksimalne x koordinate
signal min_y_reg, max_y_reg: integer;       -- Minimalne i maksimalne y koordinate
signal min_x_next, max_x_next, min_y_next, max_y_next: integer;

constant min_object_area : std_logic_vector(5 downto 0) := std_logic_vector(to_unsigned(60, 6));
constant max_object_area : std_logic_vector(12 downto 0) := std_logic_vector(to_unsigned(6000, 13));
constant max_object_width : std_logic_vector(6 downto 0) := std_logic_vector(to_unsigned(80, 7));

signal allWhite_reg, allWhite_next: std_logic;
signal objects_count_reg, objects_count_next : std_logic_vector(4 downto 0);

--constant CHARMANDER_COLOR_LOWER_RGB : std_logic_vector(23 downto 0) := "101101000101101000110010"; -- RGB: (180, 90, 50)
--constant CHARMANDER_COLOR_UPPER_RGB : std_logic_vector(23 downto 0) := "111111111000001000111100"; -- RGB: (255, 130, 60)

signal pixel_next, pixel_reg : std_logic_vector(23 downto 0);

signal lower_reg, lower_next : std_logic_vector(23 downto 0);
signal upper_reg, upper_next : std_logic_vector(23 downto 0);
signal pixel_mask_reg, pixel_mask_next : std_logic_vector(23 downto 0);
signal mask_reg, mask_next : std_logic_vector (23 downto 0);

-- Atributes that need to be defined so Vivado synthesizer maps appropriate
    -- code to DSP cells
    attribute use_dsp : string;
    attribute use_dsp of Behavioral : architecture is "yes";

begin

process(clk, reset)
begin
    if reset = '1' then
        x_reg <= (others => '0');
        y_reg <= (others => '0');
        i_reg <= (others => '0');
        j_reg <= (others => '0');
        newY_reg <= (others => '0');
        newX_reg <= (others => '0');
        allWhite_reg <= '0';
        min_x_reg <= 399;
        max_x_reg <= 0;
        min_y_reg <= 199;
        max_y_reg <= 0;
        area_reg <= 0;
        pixel_reg <= (others => '0');
        objects_count_reg <= (others => '0');
        upper_reg <= (others => '0');
        lower_reg <= (others => '0');
        pixel_mask_reg <= (others => '0');
        mask_reg <= (others => '0');
        current_state <= IDLE;
    elsif rising_edge(clk) then
        x_reg <= x_next;
        y_reg <= y_next;
        i_reg <= i_next;
        j_reg <= j_next;
        newY_reg <= newY_next;
        newX_reg <= newX_next;
        current_state <= next_state;
        allWhite_reg <= allWhite_next;
        min_x_reg <= min_x_next;
        max_x_reg <= max_x_next;
        min_y_reg <= min_y_next;
        max_y_reg <= max_y_next;
        area_reg <= area_next;
        pixel_reg <= pixel_next;
        objects_count_reg <= objects_count_next;
        upper_reg <= upper_next;
        lower_reg <= lower_next;
        mask_reg <= mask_next;
        pixel_mask_reg <= pixel_mask_next;
    end if;
end process;

process(allWhite_reg, objects_count_reg, min_x_reg, max_x_reg, min_y_reg, max_y_reg, mask_reg, bram1_indata, bram2_indata, pixel_mask_reg, current_state, lower_reg, upper_reg, start, lower_in, upper_in, bram1_indata, x_reg, y_reg, rows_in, cols_in, i_reg, j_reg, pixel_reg, newY_reg, newX_reg, area_reg)
  begin
  
    i_next <= i_reg; 
    j_next <= j_reg;
    x_next <= x_reg;
    y_next <= y_reg;
    pixel_next <= pixel_reg;
    newY_next <= newY_reg;
    newX_next <= newX_reg;
    allWhite_next <= allWhite_reg;
    upper_next <= upper_reg;
    lower_next <= lower_reg;
    pixel_mask_next <= pixel_mask_reg;
    mask_next <= mask_reg;
    bram1_en <= '0';
    bram1_we <= '0';
    bram1_addr <= (others => '0');
    bram1_outdata <= (others => '0');
    bram2_en <= '0';
    bram2_we <= '0';
    bram2_addr <= (others => '0');
    bram2_outdata <= (others => '0');
    objects_count_next <= objects_count_reg;
    area_next <= area_reg;
    min_x_next <= min_x_reg;
    max_x_next <= max_x_reg;
    min_y_next <= min_y_reg;
    max_y_next <= max_y_reg;
    ready <= '0';
    
    case current_state is
        when IDLE =>
            if start = '1' then
                ready <= '0';
                x_next <= (others => '0');
                y_next <= (others => '0');
                upper_next <= upper_in;
                lower_next <= lower_in;
                next_state <= BRAM_READ_IMAGE1;
            else
                ready <= '1';
                next_state <= IDLE;
            end if;
            
        when BRAM_READ_IMAGE1 =>
            bram1_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));
            bram1_en <= '1';
            bram1_we <= '0';       
            next_state <= TEMP1;
            
        when TEMP1 =>
              pixel_next <= bram1_indata;
              bram1_en <= '0';
              bram1_we <= '0';
            next_state <= CHECK_PIXEL;
            
        when CHECK_PIXEL =>
            if unsigned(pixel_reg(23 downto 16)) >= unsigned(lower_reg(23 downto 16)) and 
               unsigned(pixel_reg(23 downto 16)) <= unsigned(upper_reg(23 downto 16)) and 
               unsigned(pixel_reg(15 downto 8)) >= unsigned(lower_reg(15 downto 8)) and 
               unsigned(pixel_reg(15 downto 8)) <= unsigned(upper_reg(15 downto 8)) and 
               unsigned(pixel_reg(7 downto 0)) >= unsigned(lower_reg(7 downto 0)) and 
               unsigned(pixel_reg(7 downto 0)) <= unsigned(upper_reg(7 downto 0)) then
               pixel_mask_next <= "111111111111111111111111";
               next_state <= WRITE_TO_BRAM_MASK1;
            else
                pixel_mask_next <= "000000000000000000000000";
                next_state <= WRITE_TO_BRAM_MASK1;
            end if;
                     
        when WRITE_TO_BRAM_MASK1 =>
               bram2_en <= '1';
               bram2_we <= '1';
               bram2_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));
               bram2_outdata <= pixel_mask_reg;
               next_state <= TEMP;
                     
        when TEMP => 
                x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
                next_state <= MASK_INNER;
                 
        when MASK_INNER =>
            if unsigned(x_reg) >= unsigned(cols_in) then
                y_next <= std_logic_vector(to_unsigned(to_integer(unsigned(y_reg)) + 1, y_next'length));
                x_next <= (others => '0');
                next_state <= MASK_OUTER;
            else
                next_state <= BRAM_READ_IMAGE1;
            end if;

        when MASK_OUTER =>
            if unsigned(y_reg) >= unsigned(rows_in) then
                x_next <= (others => '0');
                y_next <= (others => '0');
                next_state <= BRAM_READ_IMAGE2;
            else
                next_state <= MASK_INNER;
            end if;
            
           when BRAM_READ_IMAGE2 =>                                    
                bram2_en <= '1'; 
                bram2_we <= '0';     
                bram2_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));     
                next_state <= TEMP2; 
                
           when TEMP2 =>
                pixel_mask_next <= bram2_indata;
                bram2_en <= '0';
                bram2_we <= '0';
                next_state <= BRAM_WRITE;
                
           when BRAM_WRITE =>
                bram1_en <= '1';
                bram1_we <='1';
                bram1_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));
                bram1_outdata <= pixel_mask_reg;
                next_state <= TEMP3;
           
           when TEMP3 =>
                x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
                next_state <= INC_X;
                
           when INC_X =>
                if unsigned(x_reg) >= unsigned(cols_in) then
                    y_next <= std_logic_vector(to_unsigned(to_integer(unsigned(y_reg)) + 1, y_next'length));
                    x_next <= (others => '0');
                    next_state <= INC_Y;
                else
                    next_state <= BRAM_READ_IMAGE2; 
                end if;

           when INC_Y =>
                if unsigned(y_reg) >= unsigned(rows_in) then
                    y_next <= (others => '0');
                    x_next <= (others => '0');
                    next_state <= BRAM_READ_IMAGE3;
                else
                    next_state <= INC_X;
                end if;
                       
          when BRAM_READ_IMAGE3 =>
                bram1_en <= '1';
                bram1_we <= '0';      
                bram1_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));     
                next_state <= TEMP4;
            
          when TEMP4 =>
              pixel_mask_next <= bram1_indata;
              bram1_en <= '0';
              bram1_we <= '0';
              next_state <= MASKA; 

           when MASKA =>
            if pixel_mask_reg = "111111111111111111111111" then
                next_state <= IJ;
            else               
                next_state <= XPLUS;
            end if;
            
            WHEN IJ =>
                i_next <= std_logic_vector(to_signed(-5, 4));
                j_next <= std_logic_vector(to_signed(-5, 4));
                next_state <= DILATION_I;
    
          when DILATION_I =>
            if to_integer(signed(i_reg)) > 5 then
                j_next <= std_logic_vector(signed(j_reg) + 1);
                i_next <= std_logic_vector(to_signed(-5, 4));
                next_state <= DILATION_J;
            else
                next_state <= DILATION_J;       
            end if;
        
          when DILATION_J =>
            if to_integer(signed(j_reg)) > 5 then
                next_state <= XPLUS;
            else
                newY_next <= std_logic_vector(signed(y_reg) + signed(j_reg));
                newX_next <= std_logic_vector(signed(x_reg) + signed(i_reg));
                next_state <= DILATION_END;
            end if;
            
           when DILATION_END =>
              if (unsigned(newY_reg) >= 0 and unsigned(newY_reg) < unsigned(rows_in)) and 
                 (unsigned(newX_reg) >= 0 and unsigned(newX_reg) < unsigned(cols_in)) then
                    pixel_next <= "111111111111111111111111";
                    next_state <= WRITE_TO_BRAM_MASK2;
              else
                  next_state <= XPLUS;
              end if;
                
           when WRITE_TO_BRAM_MASK2 =>
               bram2_en <= '1';
               bram2_we <= '1';
               bram2_addr <= std_logic_vector(unsigned(newY_reg) * unsigned(cols_in) + unsigned(newX_reg));
               bram2_outdata <= pixel_reg;
               next_state <= TEMP5;
               
           when TEMP5 =>
               i_next <= std_logic_vector(signed(i_reg) + 1);
               next_state <= DILATION_I;
    
           when XPLUS =>
                x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
                next_state <= DILATION_INNER;
            
           when DILATION_INNER =>
            if x_reg >= cols_in then
                y_next <= std_logic_vector(to_unsigned(to_integer(unsigned(y_reg)) + 1, y_next'length));
                x_next <= (others => '0');
                next_state <= DILATION_OUTER;
            else
                next_state <= BRAM_READ_IMAGE3;
            end if;
            
            when DILATION_OUTER =>
            if y_reg >= rows_in then
                x_next <= (others => '0');
                y_next <= (others => '0');
                next_state <= BRAM_READ_IMAGE4;
            else
                x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
                next_state <= DILATION_INNER;
            end if;
            
           when BRAM_READ_IMAGE4 =>                                    
                bram2_en <= '1'; 
                bram2_we <= '0';     
                bram2_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));     
                next_state <= TEMP6; 
                
           when TEMP6 =>
                pixel_next <= bram2_indata;
                bram2_en <= '0';
                bram2_we <= '0';
                next_state <= BRAM_WRITE1;
                
           when BRAM_WRITE1 =>
                bram1_en <= '1';
                bram1_we <='1';
                bram1_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));
                bram1_outdata <= pixel_reg;
                next_state <= TEMP7;
           
           when TEMP7 =>
                x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
                next_state <= INC1_X;
                
           when INC1_X =>
                if unsigned(x_reg) >= unsigned(cols_in) then
                    y_next <= std_logic_vector(to_unsigned(to_integer(unsigned(y_reg)) + 1, y_next'length));
                    x_next <= (others => '0');
                    next_state <= INC1_Y;
                else
                    next_state <= BRAM_READ_IMAGE4; 
                end if;

           when INC1_Y =>
                if unsigned(y_reg) >= unsigned(rows_in) then
                    y_next <= (others => '0');
                    x_next <= (others => '0');
                    next_state <= BRAM_READ_IMAGE5;
                else
                    next_state <= INC1_X;
                end if;
                
           when BRAM_READ_IMAGE5 =>
                bram1_en <= '1';
                bram1_we <= '0';      
                bram1_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));     
                next_state <= TEMP8;
            
          when TEMP8 =>
                pixel_next <= bram1_indata;
                bram1_en <= '0';
                bram1_we <= '0';
                next_state <= CHECK_PIXEL1;
                  
          when CHECK_PIXEL1 =>
                if pixel_reg = "111111111111111111111111" then
                    allWhite_next <= '1';
                    next_state <= IJ1;
                else
                    next_state <= WHITE;
                end if;
            
            when IJ1 =>
                i_next <= std_logic_vector(to_signed(-5, 4));
                j_next <= std_logic_vector(to_signed(-5, 4));
                next_state <= TEMP_I;
            
           when TEMP_I =>
            if to_integer(signed(i_reg)) > 5 then
                j_next <= std_logic_vector(signed(j_reg) + 1);
                i_next <= std_logic_vector(to_signed(-5, 4));
                next_state <= TEMP_J;
            else
                next_state <= TEMP_J;
            end if;
            
            when TEMP_J =>
            if to_integer(signed(j_reg)) > 5 then
                next_state <= WHITE;
            else
                newY_next <= std_logic_vector(signed(y_reg) + signed(j_reg));
                newX_next <= std_logic_vector(signed(x_reg) + signed(i_reg));
                next_state <= NEWW;
            end if;

          when NEWW =>
            if (unsigned(newY_reg) >= 0 and unsigned(newY_reg) < unsigned(rows_in)) and 
               (unsigned(newX_reg) >= 0 and unsigned(newX_reg) < unsigned(cols_in)) then
                 next_state <= BRAM_CHECK;
            else
                  next_state <= X1PLUS;
            end if;
            
         when BRAM_CHECK =>
                bram1_en <= '1';
                bram1_we <= '0';      
                bram1_addr <= std_logic_vector(unsigned(newY_reg) * unsigned(cols_in) + unsigned(newX_reg));     
                next_state <= TEMP9;
            
         when TEMP9 =>
                pixel_mask_next <= bram1_indata;
                bram1_en <= '0';
                bram1_we <= '0';
                next_state <= CHECK;  
            
          when CHECK =>
             if pixel_mask_reg /= "111111111111111111111111" then
                  allWhite_next <= '0';
                  next_state <= WHITE;
             else
                  i_next <= std_logic_vector(signed(i_reg) + 1);
                  next_state <= TEMP_I;
             end if;
            
          when WHITE =>
            if allWhite_reg = '1' then
                mask_next <= "111111111111111111111111";
            else
                mask_next <= "000000000000000000000000";
            end if;
                next_state <= BRAM_WRITE_PIXEL;
                
          WHEN BRAM_WRITE_PIXEL =>
               bram2_en <= '1';
               bram2_we <= '1';
               bram2_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));
               bram2_outdata <= mask_reg;
               next_state <= X1PLUS;
              
          when X1PLUS =>
                x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
                next_state <= PIXEL_INNER;
                    
          when PIXEL_INNER =>
            if unsigned(x_reg) >= unsigned(cols_in) then
                y_next <= std_logic_vector(to_unsigned(to_integer(unsigned(y_reg)) + 1, y_next'length));
                x_next <= (others => '0');
                next_state <= PIXEL_OUTER;
            else
                next_state <= BRAM_READ_IMAGE5;
            end if;

          when PIXEL_OUTER =>
             if y_reg >= rows_in then
               y_next <= (others => '0');
               x_next <= (others => '0');
               next_state <= BRAM_READ_IMAGE6;
            else
               x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
               next_state <= PIXEL_INNER;
            end if;
            
           when BRAM_READ_IMAGE6 =>                                    
                bram2_en <= '1'; 
                bram2_we <= '0';     
                bram2_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));     
                next_state <= TEMP10; 
                
           when TEMP10 =>
                mask_next <= bram2_indata;
                bram2_en <= '0';
                bram2_we <= '0';
                next_state <= BRAM_WRITE2;
                
           when BRAM_WRITE2 =>
                bram1_en <= '1';
                bram1_we <='1';
                bram1_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));
                bram1_outdata <= mask_reg;
                next_state <= TEMP11;
           
           when TEMP11 =>
                x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
                next_state <= INC2_X;
                
           when INC2_X =>
                if unsigned(x_reg) >= unsigned(cols_in) then
                    y_next <= std_logic_vector(to_unsigned(to_integer(unsigned(y_reg)) + 1, y_next'length));
                    x_next <= (others => '0');
                    next_state <= INC2_Y;
                else
                    next_state <= BRAM_READ_IMAGE6; 
                end if;

           when INC2_Y =>
                if unsigned(y_reg) >= unsigned(rows_in) then
                    y_next <= (others => '0');
                    x_next <= (others => '0');
                    next_state <= BRAM_READ_IMAGE7;
                else
                    next_state <= INC2_X;
                end if;
                
           when BRAM_READ_IMAGE7 =>
                bram1_en <= '1';
                bram1_we <= '0';      
                bram1_addr <= std_logic_vector(unsigned(y_reg) * unsigned(cols_in) + unsigned(x_reg));     
                next_state <= TEMP12;
            
          when TEMP12 =>
                mask_next <= bram1_indata;
                bram1_en <= '0';
                bram1_we <= '0';
                next_state <= CHECK_PIXEL2;
                        
          when CHECK_PIXEL2 =>
               if mask_reg = "111111111111111111111111" then
                    area_next <= area_reg + 1;
                    next_state <= CHECK_MINX;
               else
                    area_next <= area_reg;
                    next_state <= X2PLUS;
               end if;
               
         when CHECK_MINX =>
                if to_integer(unsigned(x_reg)) < min_x_reg then
                    min_x_next <= to_integer(unsigned(x_reg));
                else
                    min_x_next <= min_x_reg;   
                end if;
                next_state <= CHECK_MAXX;
         
         when CHECK_MAXX =>
                if to_integer(unsigned(x_reg)) > max_x_reg then
                    max_x_next <= to_integer(unsigned(x_reg));
                else
                    max_x_next <= max_x_reg;
                end if;
                next_state <= CHECK_MINY;
         
         when CHECK_MINY =>
                if to_integer(unsigned(y_reg)) < min_y_reg then
                    min_y_next <= to_integer(unsigned(y_reg));
                else
                    min_y_next <= min_y_reg;
                end if;
                next_state <= CHECK_MAXY;
                
        when CHECK_MAXY =>
                if to_integer(unsigned(y_reg)) > max_y_reg then
                    max_y_next <= to_integer(unsigned(y_reg));
                else
                    max_y_next <= max_y_reg;
                end if;
                next_state <= X2PLUS;

          when X2PLUS =>
            x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
            next_state <= CONTOUR_INNER;
            
         when CONTOUR_INNER =>
            if x_reg >= cols_in then
                y_next <= std_logic_vector(to_unsigned(to_integer(unsigned(y_reg)) + 1, y_next'length));
                x_next <= (others => '0');
                next_state <= CONTOUR_OUTER;
            else
                next_state <= BRAM_READ_IMAGE7;
            end if;
            
         when CONTOUR_OUTER =>
            if y_reg >= rows_in then
              x_next <= (others => '0');
              y_next <= (others => '0');
              next_state <= AREA_CHECK;
            else
              x_next <= std_logic_vector(to_unsigned(to_integer(unsigned(x_reg)) + 1, x_next'length));
              next_state <= CONTOUR_INNER;
            end if;
           
         when AREA_CHECK =>                     
            if (area_reg > to_integer(unsigned(min_object_area)) and area_reg < to_integer(unsigned(max_object_area)) and (max_x_reg - min_x_reg + 1) < to_integer(unsigned(max_object_width))) then
                objects_count_next <= std_logic_vector(to_unsigned(to_integer(unsigned(objects_count_reg)) + 1, objects_count_next'length));
            end if;
            next_state <= IDLE;
         
         when others =>
            next_state <= IDLE;
       end case;
  end process;

  objects_count_out <= objects_count_reg;

end Behavioral;