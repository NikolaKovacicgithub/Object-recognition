import cv2

# Load the image using OpenCV
image_path = '/home/desetkica/Desktop/y24-g07/Data/slika.jpg'
image = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)

if image is not None:
    height, width = image.shape
    print(f"Image dimensions: {height} x {width}")
else:
    print("Error: Could not open or find the image.")

