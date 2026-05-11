#include <linux/cdev.h>
#include <linux/kdev_t.h>
#include <linux/uaccess.h>
#include <linux/errno.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/string.h>
#include <linux/of.h>
#include <linux/mm.h> 
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/platform_device.h>
#include <linux/ioport.h>
#include <linux/semaphore.h>
#include <linux/fs.h>
#include <linux/signal.h>
#include <linux/vmalloc.h>
#include <linux/version.h>

#define WIDTH 400
#define HEIGHT 200
#define BUFF_SIZE 40
#define BRAM_SIZE_UNMARKED 80000
#define BRAM_SIZE_MARKED 80000

MODULE_LICENSE("GPL");

// Structure representing a pixel in RGB color space
struct Pixel
{
  int r; //red component
  int g; //green
  int b; //blue
};

//Arrays to store mask after each step
int mask[HEIGHT*WIDTH];
int closed_mask[HEIGHT*WIDTH];
int closed_mask2[HEIGHT*WIDTH];

// Arrays representing unmarked BRAM buffers for each color channel
int bram_r_unmarked[BRAM_SIZE_UNMARKED];
int bram_g_unmarked[BRAM_SIZE_UNMARKED];
int bram_b_unmarked[BRAM_SIZE_UNMARKED];

// Arrays representing marked BRAM buffers for each color channel
int bram_r_marked[BRAM_SIZE_MARKED];

// Semaphore for IP core access control
struct semaphore ip_sem;

// Semaphores for unmarked BRAMs (original image data)
struct semaphore bram_r_unmarked_sem;
struct semaphore bram_g_unmarked_sem;
struct semaphore bram_b_unmarked_sem;

// Semaphores for marked BRAMs (post-processing image data)
struct semaphore bram_r_marked_sem;

// Counters for unmarked BRAM usage
int cntrun =0;
int cntgun =0;
int cntbun =0;

// Counters for marked BRAM usage
int cntr =0;

// Flags signaling end of read operation from unmarked BRAM
int endReadru = 0;
int endReadbu = 0;
int endReadgu = 0;

// Flags signaling end of read operation from marked BRAM
int endReadrr = 0;

// Device driver identifiers
dev_t my_dev_id;  	// Holds major/minor numbers for the device
static struct class *my_class;  // Pointer to device class
static struct device *my_device;  // Pointer to created device node
static struct cdev *my_cdev; // Character device structure

// Function prototypes for file operations
int REC_open(struct inode *pinode, struct file *pfile);  // Open device
int REC_close(struct inode *pinode, struct file *pfile); // Close device 
static ssize_t REC_read(struct file *pfile, char __user *buf, size_t length, loff_t *offset); // Read from device
static ssize_t REC_write(struct file *pfile, const char __user *buf, size_t length, loff_t *offset); // Write to device

static int is_color_in_range(int r, int g, int b, struct Pixel lower, struct Pixel upper); // Check if a pixel is within a given RGB range 
void color_thresholding(struct Pixel lower, struct Pixel upper); // Creates a binary mask where pixels within the color range are set to 255 (white) and others to 0 (black)
void dilate(int kernel_size); // Expands white regions by setting neighboring pixels to white based on kernel size
void erode(int kernel_size); // Shrinks white regions by removing pixels that do not have all-white neighbors

// Module initialization and cleanup functions
static int __init REC_init(void);
static void __exit REC_exit(void);

// Structure defining file operations for the character device
struct file_operations my_fops =
{
	.owner = THIS_MODULE,
	.read = REC_read,
	.write = REC_write,
	.open = REC_open,
	.release = REC_close,
};


int is_color_in_range(int r, int g, int b, struct Pixel lower, struct Pixel upper)
{
	return(b >= lower.b && g >= lower.g && r >= lower.r && b <= upper.b && g <= upper.g && r <= upper.r);
}

void color_thresholding(struct Pixel lower, struct Pixel upper)
{
	int count = 0;

	for (int y = 0; y < HEIGHT; ++y)
	{
 	 for (int x = 0; x < WIDTH; ++x)
 	 {
	  if (is_color_in_range(bram_r_unmarked[y*WIDTH+x], bram_g_unmarked[y*WIDTH+x], bram_b_unmarked[y*WIDTH+x], lower, upper))
	  {
        mask[y*WIDTH+x] = 255;
	   count++;
        printk("Count %d\n",count);
       }
       else
       {
	   mask[y*WIDTH+x] = 0;
	  }
      }
	}
}

void dilate(int kernel_size)
{
	int count=0;
	memcpy(closed_mask,mask,sizeof(closed_mask));
	for (int y = kernel_size; y < HEIGHT; ++y)
	{
      for (int x = kernel_size; x < WIDTH; ++x)
      {
	  if (mask[y*WIDTH+x] == 255)
	   {
         for (int i = -kernel_size; i <= kernel_size; ++i)
         {
          for (int j = -kernel_size; j <= kernel_size; ++j)
          {
		 int newY = y + i;
		 int newX = x + j;
		      
		 if (newY >= 0 && newY < HEIGHT && newX >= 0 && newX < WIDTH)
		 {
		  count++;
	       closed_mask[newY*WIDTH+newX] = 255;
	       printk("Count %d\n",count);
		 }
          }
         }
        }
	  }
	 }
}

void erode(int kernel_size)
{
	memcpy(closed_mask2, closed_mask, sizeof(closed_mask2));
	int count =0;

	for (int y = kernel_size; y < HEIGHT; ++y)
	{
	 for (int x = kernel_size; x < WIDTH; ++x)
	 {
       int allWhite = 1;
        
       for (int i = -kernel_size; i <= kernel_size; ++i)
       {
        for (int j = -kernel_size; j <= kernel_size; ++j)
        {
         int newY = y + i;
         int newX = x + j;
              
         if (newY >= 0 && newY < HEIGHT && newX >= 0 && newX < WIDTH)
         {
          if (closed_mask[newY*WIDTH+newX] != 255)
          {
	      count++;
	      allWhite = 0;
	      printk("Count %d\n",count);
		 break;
          }
         }
        }
        if (!allWhite) break;
       }
       closed_mask2[y*WIDTH+x] = allWhite ? 255 : 0;
	 }
     }
}

ssize_t REC_read(struct file *pfile, char __user *buf, size_t length, loff_t *offset)
{
	int ret;
	char buff[BUFF_SIZE];
	int len, value;
	int minor = MINOR(pfile->f_inode->i_rdev);
		
	if(endReadru == 1)
	{
	 endReadru = 0;
      cntrun = 0;
      printk(KERN_INFO "Succesfully read from file\n");
	 return 0;
	}
	
	if(endReadgu == 1)
	{
	 endReadgu = 0;
	 cntgun = 0;
	 printk(KERN_INFO "Succesfully read from file\n");
	 return 0;
	}
	
	if(endReadbu == 1)
	{
	 endReadbu = 0;
	 cntbun = 0;
	 printk(KERN_INFO "Succesfully read from file\n");
	 return 0;
	}
	
	if(endReadrr == 1)
	{
	 endReadrr = 0;
	 cntr = 0;
	 printk(KERN_INFO "Succesfully read from file\n");
	 return 0;
	}
	
	switch(minor)
	{
	 case 0:
	  break;
		
	 case 1: // bram_r_unmarked
       if(down_interruptible(&bram_r_unmarked_sem))
       {
	   printk(KERN_INFO "Bram_R_UNMARKED: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	 
	  value = bram_r_unmarked[cntrun];
	  len = scnprintf(buff, BUFF_SIZE, "%d\n", value);
	  ret = copy_to_user(buf, buff, len);
	 
	  if(ret)
       {
	   return -EFAULT;
       }
	
	  cntrun++;
	 
	  if(cntrun == BRAM_SIZE_UNMARKED-1)
	  {
	   endReadru = 1;
	   cntrun = 0;
	  }
	 
	  up(&bram_r_unmarked_sem);
	 break;
	
      case 2: // bram_g_unmarked
	  if(down_interruptible(&bram_g_unmarked_sem))
	  {
	   printk(KERN_INFO "Bram_G_UNMARKED: semaphore: access to memory denied.\n");
        return -ERESTARTSYS;
	  }

	  value = bram_g_unmarked[cntgun];
	  len = scnprintf(buff, BUFF_SIZE, "%d\n", value);
	  ret = copy_to_user(buf, buff, len);
	
	  if(ret)
	  {
	   return -EFAULT;
	  }

	  cntgun++;
	  
	  if(cntgun == BRAM_SIZE_UNMARKED-1)
	  {
	   endReadgu = 1;
	   cntgun = 0;
	  }
	 
	  up(&bram_g_unmarked_sem);
	 break;
	
      case 3://bram_b_unmarked
	  if(down_interruptible(&bram_b_unmarked_sem))
	  {
	   printk(KERN_INFO "Bram_B_UNMARKED: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	
	  value = bram_b_unmarked[cntbun];
	  len = scnprintf(buff, BUFF_SIZE, "%d\n", value);
	  ret = copy_to_user(buf, buff, len);
	
	  if(ret)
	  {
	   return -EFAULT;
	  }

	  cntbun++;
	  
	  if(cntbun == BRAM_SIZE_UNMARKED-1)
	  {
	   endReadbu = 1;
	   cntbun = 0;
	  }
	  up(&bram_b_unmarked_sem);
	 break;
	
      case 4: // bram_r_marked
	  if(down_interruptible(&bram_r_marked_sem))
	  {
	   printk(KERN_INFO "Bram_MASK: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	
	  value = closed_mask2[cntr];
	  len = scnprintf(buff, BUFF_SIZE, "%d\n", value);
	  ret = copy_to_user(buf, buff, len);
	  printk(KERN_INFO "Bram_Mask:%d.\n", cntr);
	
	  if(ret)
	  {
	   return -EFAULT;
	  }
	
	 cntr++;
	 
	  if(cntr == BRAM_SIZE_MARKED-1)
	  {
	   endReadrr = 1;
	   cntr = 0;
	  }
	  up(&bram_r_marked_sem);
	 break;
	 
     default:
	  printk(KERN_INFO "Somethnig wrong\n");
      }
      
	return len;
}

ssize_t REC_write(struct file *pfile, const char __user *buf, size_t length, loff_t *offset)
{
	char buff[BUFF_SIZE];
	int minor = MINOR(pfile->f_inode->i_rdev);
	int start = 0;
	int ret = 0;
	int rpos = 0;
	int gpos = 0;
	int bpos = 0;
	int pixel_r_val = 0;
	int pixel_g_val = 0;
	int pixel_b_val = 0;
	
	struct Pixel lower;
	struct Pixel upper;

	ret = copy_from_user(buff, buf, length);
	
	if(ret)
     {
	 printk("copy from user failed \n");
	 return -EFAULT;
     }
  	buff[length] = '\0';
  	
  	switch(minor)
     {
      
      case 0: // IP
       if(down_interruptible(&ip_sem))
	  {
	   printk(KERN_INFO "BRAM_R_UNMARKED: semaphore: access to IP denied.\n");
	   return -ERESTARTSYS;
	  }
	 
	  if(down_interruptible(&bram_r_unmarked_sem))
	  {
	   printk(KERN_INFO "BRAM_R_UNMARKED : semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	 
       if(down_interruptible(&bram_g_unmarked_sem))
	  {
	   printk(KERN_INFO "BRAM_G_UNMARKED : semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	 
	  if(down_interruptible(&bram_b_unmarked_sem))
	  {
	   printk(KERN_INFO "BRAM_B_UNROTATED: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	 
	  if (down_interruptible(&bram_r_marked_sem))
	  {
	   printk(KERN_INFO "Bram_R_MARKED: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	 
	 
	 sscanf(buff, "%d,%d,%d,%d,%d,%d,%d\n", &start , &lower.b , &lower.g , &lower.r , &upper.b, &upper.g , &upper.r);
	 
	 printk(KERN_WARNING "%d,%d,%d,%d,%d,%d,%d\n", start , lower.b , lower.g , lower.r , upper.b, upper.g , upper.r );
	 
 	 if(ret != -EINVAL)
   	 {
  	  if(start == 0)
       {
        printk(KERN_WARNING "IP: start must be 1 to start \n");
       }
       else
       {
        color_thresholding(lower, upper);
        dilate(5);
        erode(5);
      	
        memcpy(bram_r_marked, closed_mask2, BRAM_SIZE_MARKED * sizeof(int));
        
    	  }
	 }
	
	up(&ip_sem);
	up(&bram_r_unmarked_sem);
	up(&bram_g_unmarked_sem);
	up(&bram_b_unmarked_sem);
	up(&bram_r_marked_sem);
	break; 
	
	
	 case 1:
       if(down_interruptible(&bram_r_unmarked_sem))
       {
	   printk(KERN_INFO "BRAM_R_UNMARKED: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
       }
      
       printk(KERN_WARNING "REC_write: about to write to bram_r_unmarked \n");
       sscanf(buff, "(%d,%d)", &rpos, &pixel_r_val);
       printk(KERN_WARNING "REC_write: bram pos: %d, pixel value: %d\n", rpos, pixel_r_val);
      
       if(pixel_r_val > 255)
       {
	   printk(KERN_WARNING "BRAM_R_UNMARKED: Pixel value cannot be larger than 255 \n");
       }
       else if(pixel_r_val < 0)
       {
	   printk(KERN_WARNING "BRAM_R_UNMARKED: Pixel value cannot be negative \n");
       }
       else if(rpos < 0)
       {
	   printk(KERN_WARNING "BRAM_R_UNMARKED: Pixel adr cannot be negative \n");
       }
       else if(rpos > BRAM_SIZE_UNMARKED - 1)
       {
	   printk(KERN_WARNING "BRAM_R_UNMARKED: Pixel adr cannot be larger than bram size \n");
       }
       else
       {
	   bram_r_unmarked[rpos] = pixel_r_val;
       }
      
       up(&bram_r_unmarked_sem);
      break;
      
	 case 2:
       if(down_interruptible(&bram_g_unmarked_sem))
	  {
	   printk(KERN_INFO "Bram IMG: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	 
       printk(KERN_WARNING "REC_write: about to write to bram_b_unmarked \n");
       sscanf(buff, "(%d,%d)", &gpos, &pixel_g_val);
       printk(KERN_WARNING "REC_write: bram pos: %d, pixel value: %d\n", gpos, pixel_g_val);
      
       if(pixel_g_val > 255)
       {
	   printk(KERN_WARNING "BRAM_G_UNMARKED: Pixel value cannot be larger than 255 \n");
       }
       else if(pixel_g_val < 0)
       {
	   printk(KERN_WARNING "BRAM_G_UNMARKED: Pixel value cannot be negative \n");
       }
       else if(gpos < 0)
       {
	   printk(KERN_WARNING "BRAM_G_UNMARKED: Pixel adr cannot be negative \n");
       }
       else if(gpos > BRAM_SIZE_UNMARKED  - 1)
       {
	   printk(KERN_WARNING "BRAM_G_UNMARKED: Pixel adr cannot be larger than bram size \n");
       }
       else
       {
	   bram_g_unmarked[gpos] = pixel_g_val;
	  }
        
       up(&bram_g_unmarked_sem);
      break;
    
    
	 case 3:
       if(down_interruptible(&bram_b_unmarked_sem))
	  {
	   printk(KERN_INFO "Bram IMG: semaphore: access to memory denied.\n");
	   return -ERESTARTSYS;
	  }
	 
        printk(KERN_WARNING "REC_write: about to write to bram_b_unmarked \n");
        sscanf(buff, "(%d,%d)", &bpos, &pixel_b_val);
        printk(KERN_WARNING "REC_write:brma pos: %d, pixel value: %d\n", bpos, pixel_b_val);
        
       if(pixel_b_val > 255)
       {
	   printk(KERN_WARNING "BRAM_B_UNMARKED: Pixel value cannot be larger than 255 \n");
       }
       else if(pixel_b_val < 0)
       {
	   printk(KERN_WARNING "BRAM_B_UNMARKED: Pixel value cannot be negative \n");
       }
       else if(bpos < 0)
       {
	   printk(KERN_WARNING "BRAM_B_UNMARKED: Pixel adr cannot be negative \n");
       }
       else if(bpos > BRAM_SIZE_UNMARKED  - 1)
       {
	   printk(KERN_WARNING "BRAM_B_UNMARKED: Pixel adr cannot be larger than bram size \n");
       }
       else
       {
	   bram_b_unmarked[bpos] = pixel_b_val;  
       }
      
	  up(&bram_b_unmarked_sem);
	 break;


      case 4:
	  printk(KERN_WARNING "REC_write: cannot write to   BRAM_R_MARKED \n");
	 break;
      	
      default:
	  printk(KERN_INFO "somethnig went wrong\n");
     }
	return length;	
}

int REC_open(struct inode *pinode, struct file *pfile)
{
	printk(KERN_INFO "Succesfully opened file\n");
	return 0;
}

int REC_close(struct inode *pinode, struct file *pfile)
{
    printk(KERN_INFO "Succesfully closed file\n");
    return 0;
}


static int __init REC_init(void)
{
	sema_init(&bram_r_unmarked_sem, 1);
	sema_init(&bram_g_unmarked_sem, 1);
	sema_init(&bram_b_unmarked_sem, 1);
	sema_init(&bram_r_marked_sem, 1);
	sema_init(&ip_sem, 1);

	int num_of_minors = 5;
	int ret = 0;
	
	ret = alloc_chrdev_region(&my_dev_id, 0, num_of_minors, "REC_REGION");
	
	if (ret != 0)
	{
	 printk(KERN_ERR "Failed to register char device\n");
	 return ret;
	}
	printk(KERN_INFO "Char device region allocated\n");
	
	my_class = class_create("REC_class");
	if(my_class == NULL)
	{
	 printk(KERN_ERR "Failed to create class\n");
	 goto fail_0;
	}
	printk(KERN_INFO "Class created\n");

	my_device = device_create(my_class, NULL, MKDEV(MAJOR(my_dev_id), 0), NULL, "rec_ip");
	if(my_device == NULL)
	{
	 printk(KERN_ERR "failed to create device IP\n");
	 goto fail_1;
	}
	printk(KERN_INFO "created IP\n");
	
	my_device = device_create(my_class, NULL, MKDEV(MAJOR(my_dev_id), 1), NULL, "bram_r_unmarked");
	if(my_device == NULL)
	{
	 printk(KERN_ERR "failed to create device BRAM_R_UNMARKED\n");
	 goto fail_1;
	}
	printk(KERN_INFO "created BRAM_R_UNMARKED\n");
	
	my_device = device_create(my_class, NULL, MKDEV(MAJOR(my_dev_id), 2), NULL, "bram_g_unmarked");
	if(my_device == NULL)
	{
	 printk(KERN_ERR "failed to create device BRAM_G_UNMARKED\n");
	 goto fail_1;
	}
	printk(KERN_INFO "created BRAM_G_UNMARKED\n");
	
	my_device = device_create(my_class, NULL, MKDEV(MAJOR(my_dev_id), 3), NULL, "bram_b_unmarked");
	if(my_device == NULL)
	{
	 printk(KERN_ERR "failed to create device BRAM_B_UNMARKED\n");
	 goto fail_1;
	}
	printk(KERN_INFO "created BRAM_B_UNMARKED\n");
	
	my_device = device_create(my_class, NULL, MKDEV(MAJOR(my_dev_id), 4), NULL, "bram_r_marked");
	if(my_device == NULL)
	{
	 printk(KERN_ERR "failed to create device BRAM_R_MARKED\n");
	 goto fail_1;
	}
	printk(KERN_INFO "created BRAM_R_MARKED\n");
		
	my_cdev = cdev_alloc();
	my_cdev->ops = &my_fops;
	my_cdev->owner = THIS_MODULE;
	ret = cdev_add(my_cdev, my_dev_id, 5);
	
	if(ret)
	{
	 printk(KERN_ERR "Failde to add cdev \n");
	 goto fail_2;
	}
	
	printk(KERN_INFO "cdev_added\n");
	printk(KERN_INFO "Hello from REC_driver\n");
	return 0;

	fail_2:
	 device_destroy(my_class, my_dev_id);
	
	fail_1:
	 class_destroy(my_class);
	
	fail_0:
	 unregister_chrdev_region(my_dev_id, 1);
	 return -1;
}

static void __exit REC_exit(void)
{
	printk(KERN_ALERT "REC_exit: rmmod called\n");
	cdev_del(my_cdev);
	printk(KERN_ALERT "REC_exit: cdev_del done\n");
	device_destroy(my_class, MKDEV(MAJOR(my_dev_id), 0));
	printk(KERN_INFO "REC_exit: device destroy 0\n");
	device_destroy(my_class, MKDEV(MAJOR(my_dev_id), 1));
	printk(KERN_INFO "REC_exit: device destroy 1\n");
	device_destroy(my_class, MKDEV(MAJOR(my_dev_id), 2));
	printk(KERN_INFO "REC_exit: device destroy 2\n");
	device_destroy(my_class, MKDEV(MAJOR(my_dev_id),3));
	printk(KERN_INFO "REC_exit: device destroy 3\n");
	device_destroy(my_class, MKDEV(MAJOR(my_dev_id), 4));
	printk(KERN_INFO "REC_exit: device destroy 4\n");

	class_destroy(my_class);
	printk(KERN_INFO "REC_exit: class destroy \n");
	unregister_chrdev_region(my_dev_id, 5);
	printk(KERN_INFO "REC_driver: Cleanup complete, exiting!\n");
}

module_init(REC_init);
module_exit(REC_exit);


