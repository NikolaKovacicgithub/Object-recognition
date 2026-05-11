#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <opencv2/opencv.hpp>
#include <signal.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <limits>

#define MAX_OBJECTS 10

using namespace std;

#define WIDTH 400
#define HEIGHT 200
#define BRAM_SIZE_UNMARKED 80000
#define BRAM_SIZE_MARKED 80000
#define STACK_SIZE (WIDTH * HEIGHT)
#define MIN_OBJECT_AREA 120
#define MAX_OBJECT_AREA 6050
#define MAX_OBJECT_WIDTH 300


int bram_r_unmarked[BRAM_SIZE_UNMARKED];
int bram_g_unmarked[BRAM_SIZE_UNMARKED];
int bram_b_unmarked[BRAM_SIZE_UNMARKED];

int offload_res[BRAM_SIZE_UNMARKED];


static bool read_int_choice(int &out) {
    if (!(cin >> out)) 
    {
     cin.clear();
     cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
     return false;
    }
    return true;
}

void load_image(const char *filename)
{
    FILE *file = fopen(filename, "rb"); //Opens image file
    
    if(!file)
    {
     perror("Error opening file");
     return;
    }

    int image_size = WIDTH * HEIGHT * 3; 
    unsigned char data[image_size]; //Array to store image

    //Read file
    fread(data,1,image_size,file);
    fclose(file);

    //Extract RGB values into 1d arrays
    for(int i=0, pixel=0;i<image_size; i+=3,pixel++)
    {
     bram_b_unmarked[pixel] = (int)data[i];
     bram_g_unmarked[pixel] = (int)data[i+1];
     bram_r_unmarked[pixel] = (int)data[i+2];

     printf("Pixel %d -> R: %d, G: %d, B: %d\n",pixel,bram_r_unmarked[pixel],bram_g_unmarked[pixel],bram_b_unmarked[pixel]);
    }
}

// Funkcija koja od BRAM bafera RGB pravi OpenCV sliku u BGR formatu.
static cv::Mat make_original_bgr()
{
    // OpenCV matrica dimenzija HEIGHT x WIDTH sa 3 kanala
    cv::Mat img(HEIGHT, WIDTH, CV_8UC3);
    
    // Prođi kroz sve piksele slike
    for (int y = 0; y < HEIGHT; ++y) 
    {
     for (int x = 0; x < WIDTH; ++x) 
     {
      int idx = y*WIDTH + x;
      
      img.at<cv::Vec3b>(y,x)[0] = (unsigned char)bram_r_unmarked[idx];
      img.at<cv::Vec3b>(y,x)[1] = (unsigned char)bram_g_unmarked[idx];
      img.at<cv::Vec3b>(y,x)[2] = (unsigned char)bram_b_unmarked[idx];
     }
    }
    return img;
}

/* Funkcija koja vizuelizuje rezultate obrade maske. Na osnovu maske (255 = deo objekta), pronalazi konture objekata,
   računa bounding box-eve i crta ih na kopiji originalne slike.
*/
static void render_result_image(const int *mask_in,
                                const char *label,  // ime klase
                                const char *out_path, // putanja gde će se snimiti rezultat
                                int &objects_count_out) // vraća broj detektovanih objekata
{
    std::vector<uint8_t> work(WIDTH*HEIGHT);
    for (int i = 0; i < WIDTH*HEIGHT; ++i)
        work[i] = (mask_in[i] == 255) ? 255 : 0;

    std::vector<cv::Rect> rects;

    // Susedi za flood-fill
    static const int DX[8] = {1,1,0,-1,-1,-1,0,1};
    static const int DY[8] = {0,1,1,1,0,-1,-1,-1};

    auto idx = [](int x,int y){ return y*WIDTH + x; };

    //prolazimo kroz sve piksele maske
    for (int y = 0; y < HEIGHT; ++y) 
    {
     for (int x = 0; x < WIDTH; ++x) 
     {
      if (work[idx(x,y)] != 255) continue;

      int area = 0;
      int minx = x, maxx = x, miny = y, maxy = y;
			
      // Stek za flood-fill
      std::vector<std::pair<int,int>> st;
      st.emplace_back(x,y);
      work[idx(x,y)] = 128;

      while (!st.empty()) 
      {
       auto p = st.back(); st.pop_back();
       int cx = p.first;
       int cy = p.second;

       area++;

	  // Prođi kroz sve susede
       if (cx < minx) minx = cx;
       if (cx > maxx) maxx = cx;
       if (cy < miny) miny = cy;
       if (cy > maxy) maxy = cy;

       for (int k=0;k<8;++k) 
       {
        int nx=cx+DX[k], ny=cy+DY[k];
        
        if (nx>=0 && nx<WIDTH && ny>=0 && ny<HEIGHT) 
        {
         int id = idx(nx,ny);
         if (work[id] == 255) 
         {
         work[id] = 128;
         st.emplace_back(nx,ny);
         }
        }
       }
      }
      
      // Izračunaj širinu objekta
      int w = maxx - minx + 1;
      
      // Filtriraj objekte po površini i širini
      if (area > MIN_OBJECT_AREA && area < MAX_OBJECT_AREA && w < MAX_OBJECT_WIDTH) 
      {
       rects.emplace_back(minx, miny, w, maxy - miny + 1);
      }
     }
    }
    // Napravi originalnu sliku na kojoj se ipisuje
    cv::Mat img = make_original_bgr();
    cv::Scalar draw(0,255,255);

    int counter = 0;
    for (const auto &r : rects) 
    {
     counter++;
     cv::rectangle(img, r, draw, 2); // Nacrtaj pravougaonik oko objekta
     std::string text = std::string(label) + " " + std::to_string(counter);
     int baseline=0;
     auto sz = cv::getTextSize(text, cv::FONT_HERSHEY_SIMPLEX, 0.5, 2, &baseline);
     cv::Point org(r.x, std::max(r.y-5, sz.height+2));
     cv::putText(img, text, org, cv::FONT_HERSHEY_SIMPLEX, 0.5, draw, 2);
    }

    objects_count_out = counter;
    cv::imwrite(out_path, img);
}

void pick_pokemon(int *pick)
{
	std::cout << "Main Menu\n";
	std::cout << "Please make your selection\n";
     std::cout << "0 - Red\n";
     std::cout << "1 - Green\n";
     std::cout << "2 - Blue\n";
	std::cout << "3 - Yellow\n";
	std::cout << "4 - Brown\n";
	std::cout << "5 - Pink\n";
	std::cout << "6 - White\n";
	std::cout << "7 - Black\n";
	std::cout << "8 - Dark-blue\n";
	std::cout << "9 - Purple\n";
	std::cout << "Selection: ";
	std::cin >> *pick;
}

typedef struct 
{
    int b, g, r;  // Order: BGR
} Pixel;

typedef struct 
{
    char name[20];
    Pixel lower;
    Pixel upper;
} ObjectThreshold;

//Funkcija koja pronalazi konturu, celu povezanost objekta
void find_contour(int mask[BRAM_SIZE_MARKED], int x, int y, int *area, int *min_x, int *max_x, int *min_y, int *max_y) 
{
    // Stek za flood-fill
    int stack[STACK_SIZE][2];
    int top = 0;
    
    // Stavi početnu tačku na stek
    stack[top][0] = x;
    stack[top][1] = y;
    
    // Obeleži početni piksel kao posećen
    mask[y*WIDTH+x] = 128;
    
    // Inicijalizuj površinu i bounding box
    (*area) = 0;
    *min_x = *max_x = x;
    *min_y = *max_y = y;
    
    static const int dx[] = {1, 1, 0, -1, -1, -1, 0, 1};
    static const int dy[] = {0, 1, 1, 1, 0, -1, -1, -1};
    
    while (top >= 0) 
    {
     int cx = stack[top][0];
     int cy = stack[top][1];
     top--;
     (*area)++;
        
     if (cx < *min_x) *min_x = cx;
     if (cx > *max_x) *max_x = cx;
     if (cy < *min_y) *min_y = cy;
     if (cy > *max_y) *max_y = cy;
        
     for (int i = 0; i < 8; i++) 
     {
      int nx = cx + dx[i];
      int ny = cy + dy[i];
            
      if (nx >= 0 && nx < WIDTH && ny >= 0 && ny < HEIGHT && mask[ny*WIDTH+nx] == 255) 
      {
	  mask[ny*WIDTH+nx] = 128;
       stack[++top][0] = nx;
       stack[top][1] = ny;
      }
     }
    }  
}

int main(){

    FILE * brams  ;
    FILE * ip ;
    FILE * bramres ;
    const char* filename = "image.bin";
    int x = 1;
    int r = 0;
    int total_detected = 0;
    
    int choice;
    
    int ip_fd = open("/dev/rec_ip", O_RDWR | O_CLOEXEC);
	if (ip_fd < 0) 
	{
	 perror("/dev/rec_ip");
	}
	

ObjectThreshold objects[MAX_OBJECTS] = 
{
	{"Red", {180, 90, 50}, {255, 130, 60}},
	{"Green", {80, 135, 80}, {140, 200, 135}},
	{"Blue", {100, 160, 160}, {129, 190, 189}},
	{"Yellow", {240, 210, 120}, {250, 230, 180}},
	{"Brown", {164, 135, 90}, {184, 140, 205}},
	{"Pink", {220, 170, 190}, {255, 210, 220}},
	{"White", {145, 151, 155}, {155, 180, 188}},
	{"Black", {58, 63, 65}, {85, 85, 77}},
	{"Darkblue", {220, 220, 200}, {245, 230, 220}},
	{"Purple", {165, 80, 80}, {225, 105, 105}}
};

    do 
    {
	cout << "1 - Load data \n";
	cout << "2 - Write into bram \n";
	cout << "3 - Select Pokemon \n";
	cout << "4 - Start IP \n";
	cout << "5 - Read results\n";
	cout << "6 - Finish \n";
	cout << "7 - Show processed picture \n";
	cout << "8 - Exit \n";
	cout << "Please select an action: ";

     if (!read_int_choice(choice)) 
     {
      cout << "Invalid input. Please enter a number 1-8.\n\n";
      continue;
     }
     cout << "\n";
     

    
    switch (choice) 
    {
     case 1: load_image(filename); break;
        
	//upis u bram
     case 2: 
     {
      for (int i=0;i<BRAM_SIZE_UNMARKED;++i)
      {
       brams = fopen("/dev/bram_r_unmarked","w");
       if (!brams)
       { 
        perror("/dev/bram_r_unmarked"); break; 
       }
       fprintf(brams,"(%d,%d)\n",i,bram_r_unmarked[i]);
       fclose(brams);
      }

      for (int j=0;j<BRAM_SIZE_UNMARKED;++j)
      {
       brams=fopen("/dev/bram_g_unmarked","w");
       if (!brams) 
       { 
        perror("/dev/bram_g_unmarked"); break; 
       }
       fprintf(brams,"(%d,%d)\n",j,bram_g_unmarked[j]);
       fclose(brams);
      }

      for (int k=0;k<BRAM_SIZE_UNMARKED;++k)
      {
       brams= fopen("/dev/bram_b_unmarked", "w");
       if (!brams) 
       { 
        perror("/dev/bram_b_unmarked"); break; 
       }
        fprintf(brams, "(%d,%d)\n", k, bram_b_unmarked[k]);
        fclose(brams);
      }
     break;
     }

     case 3: pick_pokemon(&x); break;

     case 4: 
     {
      // pokreni IP
      ip = fopen("/dev/rec_ip","w");
      if (!ip) 
      { 
       perror("/dev/rec_ip"); break; 
      }
      fprintf(ip,"%d,%d,%d,%d,%d,%d,%d\n", 1, (int)objects[x].lower.b , (int)objects[x].lower.g , (int)objects[x].lower.r, (int)objects[x].upper.b , (int)objects[x].upper.g , (int)objects[x].upper.r);
      fclose(ip);
      cout << "IP started.\n";
     break;
     }
     
     case 5:
     {
	 bramres = fopen("/dev/bram_r_marked","r");
	 for(int b = 0; b < BRAM_SIZE_UNMARKED; b++)
	 {
	  fscanf(bramres,"%d\n",&r);
	  offload_res[b] = r;
	  if(offload_res[b] != 0)
	  {
	   cout << offload_res[b] << "-pos "<< b << endl;
	  }
	 }
	 break;
	}

     case 6: 
     {
      //(detekcija kontura)
      int objects_count;
      int mask_copy[BRAM_SIZE_UNMARKED];
      memcpy(mask_copy, offload_res, sizeof(mask_copy));
      
      for (int w = 0; w < HEIGHT; w++)
      {
       for (int q = 0; q < WIDTH; q++)
       {
        if (mask_copy[w*WIDTH+q] == 255)
        {
         int area = 0, min_x = WIDTH, max_x = 0, min_y = HEIGHT, max_y = 0;
         find_contour(mask_copy, q, w, &area, &min_x, &max_x, &min_y, &max_y);
         int width = max_x - min_x;
         
         if (area > MIN_OBJECT_AREA && area < MAX_OBJECT_AREA && width < MAX_OBJECT_WIDTH)
         {
          objects_count++;
          printf("Detected %s Object %d - Area: %d, Width: %d, Position: (%d, %d)\n", objects[x].name, objects_count, area, width, min_x, min_y);
          total_detected++;
          printf("Total Objects Detected: %d\n", total_detected);
         }
        }
       }
      }
     break;
     }

     case 7: 
     {
      int rendered_count = 0;
      const char *out_path = "result.png";
      render_result_image(offload_res, objects[x].name, out_path, rendered_count);
      cout << "Rendered " << rendered_count << " object(s) for class " << objects[x].name << " -> saved to " << out_path << endl;
      cv::Mat result = cv::imread(out_path);
      
      if (!result.empty()) 
      {
       cv::imshow("Processed picture", result);
       cv::waitKey(0);
      }
     break;
     }

     case 8: cout << "End \n"; if (ip_fd >= 0) close(ip_fd); return 0;

     default:
      cout << "Please choose 1-8!\n";
     break;

    }

}while (true);

return 0;
} // main
