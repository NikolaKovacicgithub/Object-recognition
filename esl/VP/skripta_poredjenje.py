import cv2
import numpy as np
import matplotlib.pyplot as plt

def compare_images(img1_path, img2_path):
    # Load the images
    img1 = cv2.imread(img1_path)
    img2 = cv2.imread(img2_path)

    # Check if images are loaded properly
    if img1 is None:
        print(f"Error: Could not load image at {img1_path}")
        return
    if img2 is None:
        print(f"Error: Could not load image at {img2_path}")
        return

    # Resize images to the same size if necessary (shouldn't be needed if images are the same size)
    if img1.shape != img2.shape:
        print("Warning: Images have different shapes. Resizing for comparison.")
        img2 = cv2.resize(img2, (img1.shape[1], img1.shape[0]))

    # Compute the absolute difference between the two images
    difference = cv2.absdiff(img1, img2)
    b, g, r = cv2.split(difference)

    # Check for any non-zero values (indicating differences)
    if np.count_nonzero(b) == 0 and np.count_nonzero(g) == 0 and np.count_nonzero(r) == 0:
        print("The images are identical.")
    else:
        print("The images are different.")

    # Calculate and print a summary of differences
    num_diff_pixels = np.count_nonzero(difference)
    total_pixels = img1.shape[0] * img1.shape[1] * img1.shape[2]
    diff_percentage = (num_diff_pixels / total_pixels) * 100

    print(f"Number of different pixels: {num_diff_pixels}")
    print(f"Total number of pixels: {total_pixels}")
    print(f"Difference percentage: {diff_percentage:.2f}%")

    # Visualize the difference image
    plt.imshow(cv2.cvtColor(difference, cv2.COLOR_BGR2RGB))
    plt.title('Difference Image')
    plt.axis('off')
    plt.show()

    # Optionally: Save the difference image
    diff_image_path = 'difference2.jpg'
    cv2.imwrite(diff_image_path, difference)
    print(f"Difference image saved to {diff_image_path}")

# Paths to the original and output images
original_image_path = '/home/desetkica/Desktop/y24-g07/Data/picture_24.jpg'
output_image_path = '/home/desetkica/Desktop/output_image.jpg'

# Compare the images
compare_images(original_image_path, output_image_path)

