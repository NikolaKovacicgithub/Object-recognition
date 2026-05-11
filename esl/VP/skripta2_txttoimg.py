import numpy as np
import cv2

def txt_to_image(txt_file, output_image, image_shape):
    # Read the decimal values from the text file
    with open(txt_file, 'r') as file:
        data = file.read().split()

    # Convert the list of strings to a list of integers
    pixel_values = list(map(int, data))

    # Ensure the number of pixel values matches the product of the image dimensions and channels
    if len(pixel_values) != image_shape[0] * image_shape[1] * 3:
        raise ValueError(f"Number of pixel values ({len(pixel_values)}) does not match the expected size ({image_shape[0] * image_shape[1] * 3}).")

    # Convert the list to a numpy array and reshape it to the original image dimensions with 3 channels
    image_array = np.array(pixel_values, dtype=np.uint8).reshape((image_shape[0], image_shape[1], 3))

    # Save the numpy array as an image
    cv2.imwrite(output_image, image_array)
    print(f"Image saved to {output_image}")

# Define the image shape (height, width)
image_shape = (200, 400)  # Replace with actual dimensions if different

# Convert the text file to an image
txt_to_image('/home/desetkica/Desktop/bram_memory2.txt', '/home/desetkica/Desktop/output_image.jpg', image_shape)

