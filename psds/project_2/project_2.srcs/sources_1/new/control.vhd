library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_path is
  port (
    clk           : in std_logic;
    reset         : in std_logic;
    start         : in std_logic;
    rows          : in unsigned(8 downto 0);  -- Broj redova slike
    cols          : in unsigned(8 downto 0);  -- Broj kolona slike
    channels      : in unsigned(2 downto 0);  -- Broj kanala (RGB)
    lower         : in std_logic_vector(23 downto 0);  -- Donja granica boja (RGB)
    upper         : in std_logic_vector(23 downto 0);  -- Gornja granica boja (RGB)
    pixel_mem     : in std_logic_vector(255 downto 0);  -- Memorija slike (piksela)
    mask_mem      : in std_logic_vector(255 downto 0);  -- Memorija maske
    mask_next     : out std_logic_vector(255 downto 0); -- Obradjena maska slike (processed image)
    objects_count : out integer range 0 to 10000  -- Broj detektovanih objekata
  );
end control_path;


architecture Behavioral of control_path is
  -- Tipovi stanja
  type state_type is (IDLE, MASK_OUTER, MASK_INNER, PIXEL, DILATION_OUTER, DILATION_INNER, MASKA, DILATION_I, DILATION_J, DILATION_END, XPLUS, PIXEL_OUTER, PIXEL_INNER, X1PLUS, TEMP_EXPAND, WHITE, TEMP_J, NEWW, IPLUS, CONTOUR_OUTER, CONTOUR_INNER, FIND_CONTOURS_WHILE, VISITE, END_CONTOUR, X2PLUS, AREA_CHECK, PIXEL_CHECK, FIND_CONTOURS_I, RECTANGLE_LOOP, RECTANGLE_HORIZONTAL_LOOP, RECTANGLE_VERTICAL, RECTANGLE_TOP, COLOR_VERTICAL, FINISH);
  signal current_state, next_state: state_type;

  -- Signali za pra?enje trenutnih koordinata piksela
signal x_reg, y_reg: unsigned(8 downto 0);
signal i_reg, j_reg: integer range -5 to 5;
signal newY_reg, newX_reg: integer range 0 to 511;
signal stack_size_reg: integer range 0 to 10000;

  -- Promenljive za pra?enje kontura
signal area: integer := 0;                -- Površina konture
signal min_x, max_x: integer := 0;        -- Minimalne i maksimalne x koordinate
signal min_y, max_y: integer := 0;        -- Minimalne i maksimalne y koordinate
signal width: integer := 0;

signal objects_count_reg: integer range 0 to 10000 := 0; 
  -- Broja? objekata
 signal rect_color : std_logic_vector(23 downto 0);  -- za RGB boje, svaka boja po 8 bita

  -- Stek za cuvanje tacaka (x, y) koje treba da budu obranene tokom pretrage kontura
  type point_type is record
    x: integer;
    y: integer;
  end record;
type stack_array_type is array(0 to 10000) of point_type;
signal stack: stack_array_type;

signal allWhite_reg: std_logic;
signal mask_addr : unsigned(17 downto 0);
signal closed_mask: std_logic_vector(255 downto 0);
signal visited: std_logic_vector(255 downto 0);  -- Signal za pracenje posecenih piksela

  -- Signali za pracenje trenutnih koordinata tacke sa steka
signal cx, cy: integer range 0 to 511;
signal Point_current: point_type;

constant min_object_area : integer := 60;
constant max_object_area : integer := 6000;
constant max_object_width : integer := 600;

type int_array is array (0 to 7) of integer;
constant dx : int_array := (1, 1, 0, -1, -1, -1, 0, 1);
constant dy : int_array := (0, 1, 1, 1, 0, -1, -1, -1);
  
signal pixel_top      : std_logic_vector(23 downto 0); -- RGB piksel za gornju ivicu
signal pixel_bottom   : std_logic_vector(23 downto 0); -- RGB piksel za donju ivicu
signal pixel_left     : std_logic_vector(23 downto 0); -- RGB piksel za levu ivicu
signal pixel_right    : std_logic_vector(23 downto 0); -- RGB piksel za desnu ivicu
signal c_next: integer range 0 to 2;  -- RGB kanali (R, G, B) imaju opseg od 0 do 2
signal c_reg: integer range 0 to 2;   -- Registrovana vrednost za trenutni RGB kanal
signal pixel_addr : unsigned(16 downto 0);
   
signal x_next, y_next: unsigned(8 downto 0);
signal i_next, j_next: integer range -5 to 5;
signal newY_next, newX_next: integer range 0 to 511;
signal stack_size_next: integer range 0 to 10000;
signal allWhite_next: std_logic;
signal objects_count_next: integer range 0 to 10000;
signal pixel_addr_next: unsigned(16 downto 0);
signal mask_next_next: std_logic_vector(255 downto 0);
signal mask_addr_next: unsigned(17 downto 0);
signal min_x_next, max_x_next, min_y_next, max_y_next: integer;
signal area_next: integer range 0 to 10000;
signal cx_next, cy_next: integer range 0 to 511;
signal visited_next: std_logic_vector(255 downto 0);
signal cx_reg, cy_reg: integer range 0 to 511;
signal width_next : integer;
signal color_index_next: integer range 0 to 3;
signal color_index_reg: integer range 0 to 3;
signal rect_color_next: std_logic_vector(23 downto 0);
signal pixel_top_next, pixel_bottom_next: std_logic_vector(23 downto 0);
signal pixel_left_next, pixel_right_next: std_logic_vector(23 downto 0);

constant CHARMANDER_COLOR_LOWER : std_logic_vector(23 downto 0) := "001100101101101011000010"; -- RGB: (50, 90, 180)
constant CHARMANDER_COLOR_UPPER : std_logic_vector(23 downto 0) := "001111000100100011111111"; -- RGB: (60, 130, 255)


begin

  -- Proces za ažuriranje registrovanih signala
process(clk, reset)
begin
    if reset = '1' then
        x_reg <= (others => '0');
        y_reg <= (others => '0');
        i_reg <= 0;
        j_reg <= 0;
        newY_reg <= 0;
        newX_reg <= 0;
        pixel_addr <= (others => '0');
        mask_next_next <= (others => '0');
        stack_size_reg <= 0;
        mask_addr <= (others => '0');
        allWhite_reg <= '0';
        min_x <= 511;
        max_x <= 0;
        min_y <= 511;
        max_y <= 0;
        area <= 0;
        cx_reg <= 0;
        cy_reg <= 0;
        width <= 0;
        pixel_top <= (others => '0');
        pixel_bottom <= (others => '0');
        c_reg <= 0;
        objects_count_reg <= 0;
        rect_color <= (others => '0');
        pixel_left <= (others => '0');
        pixel_right <= (others => '0');
        current_state <= IDLE;
    elsif rising_edge(clk) then
        x_reg <= x_next;
        y_reg <= y_next;
        i_reg <= i_next;
        j_reg <= j_next;
        newY_reg <= newY_next;
        newX_reg <= newX_next;
        pixel_addr <= pixel_addr_next;
        mask_next_next <= closed_mask;
        current_state <= next_state;
        stack_size_reg <= stack_size_next;
        mask_addr <= mask_addr_next;
        allWhite_reg <= allWhite_next;
        min_x <= min_x_next;
        max_x <= max_x_next;
        min_y <= min_y_next;
        max_y <= max_y_next;
        area <= area_next;
        cx_reg <= cx_next;
        cy_reg <= cy_next;
        width <= width_next;
        objects_count_reg <= objects_count_next;
        rect_color <= rect_color_next;
        pixel_top <= pixel_top_next;
        pixel_bottom <= pixel_bottom_next;
        c_reg <= c_next;
        pixel_left <= pixel_left_next;
        pixel_right <= pixel_right_next;
    end if;
end process;

process(current_state, x_reg, y_reg, cols, mask_mem, mask_next_next, i_reg, j_reg, visited)
  begin
  
    i_next <= i_reg; 
    j_next <= j_reg;
    x_next <= x_reg;
    y_next <= y_reg;
    pixel_addr_next <= pixel_addr;
    mask_addr_next <= mask_addr;
    closed_mask <= mask_next_next;  
    newY_next <= newY_reg;
    newX_next <= newX_reg;
    stack_size_next <= stack_size_reg;
    allWhite_next <= allWhite_reg;
    
    case current_state is
        when IDLE =>
            if start = '1' then
                x_next <= (others => '0');
                y_next <= (others => '0');
                next_state <= MASK_OUTER;
            else
                next_state <= IDLE;
            end if;

        when MASK_OUTER =>
            if y_reg >= rows then
                x_next <= (others => '0');
                y_next <= (others => '0');
                next_state <= DILATION_OUTER;
            else
                x_next <= (others => '0');
                next_state <= MASK_INNER;
            end if;
    
          when MASK_INNER =>
            if x_reg >= cols then
                y_next <= y_reg + 1;
                next_state <= MASK_OUTER;
            else
                pixel_addr_next <= resize(y_reg * cols + x_reg, pixel_addr_next'length);
                next_state <= PIXEL;
            end if;

        when PIXEL =>
            if unsigned(pixel_mem(23 downto 16)) >= unsigned(lower(23 downto 16)) and 
               unsigned(pixel_mem(23 downto 16)) <= unsigned(upper(23 downto 16)) and 
               unsigned(pixel_mem(15 downto 8)) >= unsigned(lower(15 downto 8)) and 
               unsigned(pixel_mem(15 downto 8)) <= unsigned(upper(15 downto 8)) and 
               unsigned(pixel_mem(7 downto 0)) >= unsigned(lower(7 downto 0)) and 
               unsigned(pixel_mem(7 downto 0)) <= unsigned(upper(7 downto 0)) then
                closed_mask(to_integer(pixel_addr)) <= '1';
                x_next <= x_reg + 1;
                next_state <= MASK_INNER;
            else
                x_next <= x_reg + 1;
                next_state <= MASK_INNER;
            end if;

      when DILATION_OUTER =>
    if y_reg >= rows then
        x_next <= (others => '0');
        y_next <= (others => '0');
        next_state <= PIXEL_OUTER;
    else
        x_next <= (others => '0');
        next_state <= DILATION_INNER;
    end if;
   
       when DILATION_INNER =>
    if x_reg >= cols then
        y_next <= y_reg + 1;
        next_state <= DILATION_OUTER;
    else
        next_state <= MASKA;
    end if;

       when MASKA =>
    mask_addr_next <= resize(y_reg * cols + x_reg, mask_addr'length);
    if mask_mem(to_integer(mask_addr) * 8 + 7 downto to_integer(mask_addr) * 8) = X"FF" then
        i_next <= -5;
        next_state <= DILATION_I;
    else
        next_state <= XPLUS;
    end if;

      when DILATION_I =>
    if i_reg > 5 then
        j_next <= -5;
        next_state <= DILATION_J;
    else
        next_state <= XPLUS;
    end if;
    
      when DILATION_J =>
    if j_reg > 5 then
        i_next <= i_reg + 1;
        next_state <= DILATION_I;
    else
        newY_next <= to_integer(y_reg) + i_reg;
        newX_next <= to_integer(x_reg) + j_reg;
        next_state <= DILATION_END;
    end if;

       when DILATION_END =>
          if (newY_reg >= 0 and newY_reg < to_integer(rows)) and (newX_reg >= 0 and newX_reg < to_integer(cols)) then
              closed_mask(newY_reg * to_integer(cols) + newX_reg) <= '1';
          end if;
              j_next <= j_reg + 1;
              next_state <= DILATION_J;

         when XPLUS =>
            x_next <= x_reg + 1;
            next_state <= DILATION_INNER;

      when PIXEL_OUTER =>
        if y_reg >= rows then
          stack_size_next <= 0;
          y_next <= (others => '0');
          next_state <= CONTOUR_OUTER;
        else
          x_next <= (others => '0');
          next_state <= PIXEL_INNER;
        end if;

      when PIXEL_INNER =>
            mask_addr_next <= resize(y_reg * cols + x_reg, mask_addr'length);
            if x_reg >= cols then
                y_next <= y_reg + 1;
                next_state <= PIXEL_OUTER;
            else
                if mask_next_next(to_integer(mask_addr)) = '1' then
                    allWhite_next <= '1';
                    i_next <= -5;
                    next_state <= TEMP_EXPAND;
                else
                    next_state <= X1PLUS;
                end if;
            end if;

          when TEMP_EXPAND =>
            if i_reg > 5 then
                next_state <= WHITE;
            else
                j_next <= -5;
                next_state <= TEMP_J;
            end if;
    
        when WHITE =>
            mask_addr_next <= y_reg * cols + x_reg;
            if allWhite_reg = '1' then
                closed_mask(to_integer(mask_addr)) <= '1';
            else
                closed_mask(to_integer(mask_addr)) <= '0';
            end if;
                next_state <= X1PLUS;
                
         when X1PLUS =>
            x_next <= x_reg + 1;
            next_state <= PIXEL_INNER;
    
      when TEMP_J =>
        if j_reg > 5 then
            next_state <= IPLUS;
        else
            newY_next <= to_integer(y_reg) + i_reg;
            newX_next <= to_integer(x_reg) + j_reg;
            next_state <= NEWW;
        end if;

      when IPLUS =>
        i_next <= i_reg + 1;
        next_state <= TEMP_EXPAND;

      when NEWW =>
        if (newY_reg >= 0 and newY_reg < to_integer(rows)) and (newX_reg >= 0 and newX_reg < to_integer(cols)) then
            if mask_next_next(newY_reg * to_integer(cols) + newX_reg) /= '1' then
                allWhite_next <= '0';
                next_state <= IPLUS;
            else
                j_next <= j_reg + 1;
                next_state <= TEMP_J;
            end if;
        else
            j_next <= j_reg + 1;
            next_state <= TEMP_J;
        end if;

      when CONTOUR_OUTER =>
        if y_reg >= rows then
          next_state <= FINISH;
        else
          x_next <= (others => '0');
          next_state <= CONTOUR_INNER;
        end if;

      when CONTOUR_INNER =>
    mask_addr <= resize(y_reg * cols + x_reg, mask_addr'length);
    if x_reg >= cols then
        y_next <= y_reg + 1;
        next_state <= CONTOUR_OUTER;
    else
        if (mask_next_next(to_integer(mask_addr)) = '1') and (visited(to_integer(mask_addr)) = '0') then
            area_next <= 0;
            min_x_next <= to_integer(cols);
            max_x_next <= 0;
            min_y_next <= to_integer(rows);
            max_y_next <= 0;
            stack(stack_size_next) <= (x => to_integer(x_reg), y => to_integer(y_reg));
            stack_size_next <= stack_size_reg + 1;
            next_state <= FIND_CONTOURS_WHILE;
        else
            next_state <= X2PLUS;
        end if;
    end if;

          when FIND_CONTOURS_WHILE =>
            if stack_size_reg <= 0 then
                width_next <= max_x - min_x + 1;
                next_state <= AREA_CHECK;
            else
                Point_current <= stack(stack_size_reg - 1);
                cx_next <= Point_current.x;
                cy_next <= Point_current.y;
                stack_size_next <= stack_size_reg - 1;
            end if;

        when VISITE =>
            if (visited(cy_reg * to_integer(cols) + cx_reg) = '0') and (mask_next_next(cy_reg * to_integer(cols) + cx_reg) = '1') then visited_next(cy_reg * to_integer(cols) + cx_reg) <= '1';
                area_next <= area + 1;
                next_state <= PIXEL_CHECK;
            else
                next_state <= FIND_CONTOURS_WHILE;
            end if;

      when PIXEL_CHECK =>
        if cx_reg < min_x then
            min_x_next <= cx_reg;
        elsif cx_reg > max_x then
            max_x_next <= cx_reg;
        elsif cy_reg < min_y then
            min_y_next <= cy_reg;
        elsif cy_reg > max_y then
            max_y_next <= cy_reg;
        end if;
        i_next <= 0;
        next_state <= FIND_CONTOURS_I;

        when FIND_CONTOURS_I =>
            if i_reg >= 8 then
                next_state <= FIND_CONTOURS_WHILE;
            else
                newX_next <= cx_reg + dx(i_reg);
                newY_next <= cy_reg + dy(i_reg);
                next_state <= END_CONTOUR;
            end if;

         when END_CONTOUR =>
            if (newX_reg >= 0 and newX_reg < to_integer(cols)) and (newY_reg >= 0 and newY_reg < to_integer(rows)) then
                stack(stack_size_reg) <= (x => newX_reg, y => newY_reg);
                stack_size_next <= stack_size_reg + 1;
            end if;
            i_next <= i_reg + 1;
            next_state <= FIND_CONTOURS_I;

          when AREA_CHECK =>
            if (area > min_object_area and area < max_object_area and width < max_object_width) then
                objects_count_next <= objects_count_reg + 1;
                next_state <= RECTANGLE_LOOP;
            else
                next_state <= X2PLUS;
            end if;

          when RECTANGLE_LOOP =>
            if i_reg >= 3 then
                i_next <= min_x;
                next_state <= RECTANGLE_HORIZONTAL_LOOP;
            else
                rect_color_next(i_reg * 8 + 7 downto i_reg * 8) <= std_logic_vector(to_unsigned((to_integer(unsigned(lower(i_reg * 8 + 7 downto i_reg * 8))) + to_integer(unsigned(upper(i_reg * 8 + 7 downto i_reg * 8)))) / 2, 8));
                i_next <= i_reg + 1;
                next_state <= RECTANGLE_LOOP;
            end if;


         when RECTANGLE_HORIZONTAL_LOOP =>
            if i_reg > max_x then
                i_next <= min_y;
                next_state <= RECTANGLE_VERTICAL;
            else
                pixel_top_next <= pixel_mem(to_integer(min_y * cols + i_reg) * to_integer(channels) + 23 downto to_integer(min_y * cols + i_reg) * to_integer(channels));
                pixel_bottom_next <= pixel_mem(to_integer(max_y * cols + i_reg) * to_integer(channels) + 23 downto to_integer(max_y * cols + i_reg) * to_integer(channels));
                c_next <= 0;
                next_state <= RECTANGLE_TOP;
            end if;

          when RECTANGLE_VERTICAL =>
            if i_reg > max_y then
                next_state <= X2PLUS;
            else
                pixel_left_next <= pixel_mem(to_integer(i_reg * cols + min_x) * to_integer(channels) + 23 downto to_integer(i_reg * cols + min_x) * to_integer(channels));
                pixel_right_next <= pixel_mem(to_integer(i_reg * cols + max_x) * to_integer(channels) + 23 downto to_integer(i_reg * cols + max_x) * to_integer(channels));
                c_next <= 0;
                next_state <= COLOR_VERTICAL;
            end if;

        when COLOR_VERTICAL =>
            if c_reg >= 2 then
                i_next <= i_reg + 1;
                next_state <= RECTANGLE_VERTICAL;
            else
                pixel_left(c_reg * 8 + 7 downto c_reg * 8) <= rect_color(c_reg * 8 + 7 downto c_reg * 8);
                pixel_right(c_reg * 8 + 7 downto c_reg * 8) <= rect_color(c_reg * 8 + 7 downto c_reg * 8);
                c_next <= c_reg + 1;
                next_state <= COLOR_VERTICAL;
            end if;

      when X2PLUS =>
        x_next <= x_reg + 1;
        next_state <= CONTOUR_INNER;

      when FINISH =>
        next_state <= FINISH;

      when others =>
        next_state <= IDLE;
    end case;
  end process;

  -- Dodela izlaznih signala
  mask_next <= closed_mask;
  objects_count <= objects_count_reg;

end Behavioral;

