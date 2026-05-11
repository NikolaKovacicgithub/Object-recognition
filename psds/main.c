#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_ROWS 400
#define MAX_COLS 200
#define min_object_area 60
#define max_object_area 6000
#define max_object_width 600

#define IMAGE_WIDTH 10
#define IMAGE_HEIGHT 10

typedef struct {
    int x, y;
} Point;

typedef struct {
    int height;
    int width;
    int channels;
    unsigned char* data;
} Image;

static const int dx[] = {1, 1, 0, -1, -1, -1, 0, 1};
static const int dy[] = {0, 1, 1, 1, 0, -1, -1, -1};

void processColorContours(const Image* img, const unsigned char* lower, const unsigned char* upper, const char* label, int* objects_count, Image* marked_image) {
    int rows = img->height;
    int cols = img->width;
    int channels = img->channels;

    unsigned char mask[MAX_ROWS * MAX_COLS] = {0};
    unsigned char closed_mask[MAX_ROWS * MAX_COLS] = {0};
    unsigned char temp_mask[MAX_ROWS * MAX_COLS] = {0};
    unsigned char visited[MAX_ROWS * MAX_COLS] = {0};
    Point stack[MAX_ROWS * MAX_COLS];

    int y = 0;
    int x = 0;

    // Create the mask
    create_mask_outer:
        if (y >= rows) goto end_create_mask_outer;
        x = 0;
    create_mask_inner:
        if (x >= cols) goto end_create_mask_inner;
        const unsigned char* pixel = img->data + (y * cols + x) * channels;
        if (pixel[0] >= lower[0] && pixel[1] >= lower[1] && pixel[2] >= lower[2] &&
            pixel[0] <= upper[0] && pixel[1] <= upper[1] && pixel[2] <= upper[2]) {
            mask[y * cols + x] = 255;
        }
        x++;
        goto create_mask_inner;
    end_create_mask_inner:
        y++;
        goto create_mask_outer;
    end_create_mask_outer:

    // Simple dilation to fill small holes
    memcpy(closed_mask, mask, rows * cols * sizeof(unsigned char));

    y = 0;
    x = 0;
    dilation_outer:
        if (y >= rows) goto end_dilation_outer;
        x = 0;
    dilation_inner:
        if (x >= cols) goto end_dilation_inner;
        if (mask[y * cols + x] == 255) {
            int i = -5;
        dilation_i:
            if (i > 5) goto end_dilation_i;
            int j = -5;
        dilation_j:
            if (j > 5) goto end_dilation_j;
            int newY = y + i;
            int newX = x + j;
            if (newY >= 0 && newY < rows && newX >= 0 && newX < cols) {
                closed_mask[newY * cols + newX] = 255;
            }
            j++;
            goto dilation_j;
        end_dilation_j:
            i++;
            goto dilation_i;
        end_dilation_i:
            ;
        }
        x++;
        goto dilation_inner;
    end_dilation_inner:
        y++;
        goto dilation_outer;
    end_dilation_outer:

    memcpy(temp_mask, closed_mask, rows * cols * sizeof(unsigned char));

    y = 0;
    x = 0;
    check_temp_pixel_outer:
        if (y >= rows) goto end_check_temp_pixel_outer;
        x = 0;
    check_temp_pixel_inner:
        if (x >= cols) goto end_check_temp_pixel_inner;
        if (closed_mask[y * cols + x] == 255) {
            int allWhite = 1;
            int i = -5;
        check_temp_expand:
            if (i > 5) goto end_check_temp_expand;
            int j = -5;
        check_temp_j:
            if (j > 5) goto end_check_temp_j;
            int newY = y + i;
            int newX = x + j;
            if (newY >= 0 && newY < rows && newX >= 0 && newX < cols) {
                if (temp_mask[newY * cols + newX] != 255) {
                    allWhite = 0;
                    goto end_check_temp_j;
                }
            }
            j++;
            goto check_temp_j;
        end_check_temp_j:
            i++;
            goto check_temp_expand;
        end_check_temp_expand:
            closed_mask[y * cols + x] = allWhite ? 255 : 0;
        }
        x++;
        goto check_temp_pixel_inner;
    end_check_temp_pixel_inner:
        y++;
        goto check_temp_pixel_outer;
    end_check_temp_pixel_outer:

    int stack_size = 0;
    y = 0;
    find_contours_outer:
        if (y >= rows) goto end_find_contours_outer;
        x = 0;
    find_contours_inner:
        if (x >= cols) goto end_find_contours_inner;
        if (closed_mask[y * cols + x] == 255 && visited[y * cols + x] == 0) {
            int area = 0;
            int min_x = cols, max_x = 0, min_y = rows, max_y = 0;
            stack[stack_size++] = (Point){x, y};

        find_contours_while:
            if (stack_size <= 0) goto end_find_contours_while;
            Point current = stack[--stack_size];
            int cx = current.x;
            int cy = current.y;
            if (visited[cy * cols + cx] == 0 && closed_mask[cy * cols + cx] == 255) {
                visited[cy * cols + cx] = 255;
                area++;
                if (cx < min_x) min_x = cx;
                if (cx > max_x) max_x = cx;
                if (cy < min_y) min_y = cy;
                if (cy > max_y) max_y = cy;
                int i = 0;
            find_contours_while_i:
                if (i >= 8) goto end_find_contours_while_i;
                int newX = cx + dx[i];
                int newY = cy + dy[i];
                if (newX >= 0 && newX < cols && newY >= 0 && newY < rows) {
                    stack[stack_size++] = (Point){newX, newY};
                }
                i++;
                goto find_contours_while_i;
            end_find_contours_while_i:
                ;
            }
            goto find_contours_while;
        end_find_contours_while:

        int width = max_x - min_x + 1;
        if (area > min_object_area && area < max_object_area && width < max_object_width) {
            (*objects_count)++;
        }
        }
}

// Helper function to print image
void printImage(const Image* img) {
    for (int y = 0; y < img->height; y++) {
        for (int x = 0; x < img->width; x++) {
            unsigned char* pixel = img->data + (y * img->width + x) * img->channels;
            printf("(%3d,%3d,%3d) ", pixel[0], pixel[1], pixel[2]);
        }
        printf("\n");
    }
}

int main() {
    // Create a 10x10 image with 3 channels (RGB)
    Image img;
    img.height = IMAGE_HEIGHT;
    img.width = IMAGE_WIDTH;
    img.channels = 3; // RGB
    img.data = (unsigned char*)malloc(img.height * img.width * img.channels * sizeof(unsigned char));

    // Fill image with values from 0 to 99
    for (int i = 0; i < img.height * img.width * img.channels; i++) {
        img.data[i] = i % 100;  // Values from 0 to 99
    }

    // Marked image (same size)
    Image marked_image;
    marked_image.height = IMAGE_HEIGHT;
    marked_image.width = IMAGE_WIDTH;
    marked_image.channels = 3; // RGB
    marked_image.data = (unsigned char*)malloc(marked_image.height * marked_image.width * marked_image.channels * sizeof(unsigned char));
    memset(marked_image.data, 0, marked_image.height * marked_image.width * marked_image.channels); // Initialize to black

    // Define lower and upper bounds for a color (e.g., green)
    unsigned char lower[3] = {30, 30, 30};  // Lower bound
    unsigned char upper[3] = {70, 70, 70};  // Upper bound

    // Object count
    int objects_count = 0;

    // Process contours
    processColorContours(&img, lower, upper, "Object", &objects_count, &marked_image);

    // Print original image
    printf("Original Image:\n");
    printImage(&img);

    // Print marked image
    printf("\nMarked Image (with object contours):\n");
    printImage(&marked_image);

    // Print the number of objects found
    printf("\nObjects found: %d\n", objects_count);

    // Free memory
    free(img.data);
    free(marked_image.data);

    return 0;
}


