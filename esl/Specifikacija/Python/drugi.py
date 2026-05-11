import cv2
import numpy as np

def load_image(path):
    return cv2.imread(path, cv2.IMREAD_COLOR)

def display_image(image):
    cv2.imshow('Image', image)
    cv2.waitKey(0)
    cv2.destroyAllWindows()

# Load the image
img = load_image("C:/Projekat/PR1/pictures2/picture_24.jpg")

# Define masks for green and red colors
mask_green = cv2.inRange(img, (100, 135, 80), (135, 200, 140))  # Green color range in BGR
mask_red = cv2.inRange(img, (50, 120, 240), (80, 230, 255))  # Red color range in BGR
mask_blue = cv2.inRange(img, (173, 152, 100), (208, 200, 142))  # Blue color range in BGR
mask_yellow = cv2.inRange(img, (90, 110, 215), (125, 215, 245))  # Blue color range in BGR
mask_brown = cv2.inRange(img, (90, 140, 190), (115, 160, 200))  # Define the brown color range in BGR
mask_pink = cv2.inRange(img, (190, 170, 220), (220, 210, 255))  # Pink color range in BGR
mask_white = cv2.inRange(img, (150, 140, 130), (190, 170, 150))  # White color range in BGR
mask_black = cv2.inRange(img, (60, 60, 60), (80, 80, 80))  # Black color range in BGR
mask_dark_blue = cv2.inRange(img, (130, 105, 30), (150, 120, 60))  # Dark blue color range in BGR
mask_purple = cv2.inRange(img, (80, 80, 140), (105, 105, 225))  # Purple color range in BGR
display_image(mask_red)


# Perform morphological closing for both masks
closed_mask_green = cv2.morphologyEx(mask_green, cv2.MORPH_CLOSE, np.ones((10, 10), np.uint8))
closed_mask_red = cv2.morphologyEx(mask_red, cv2.MORPH_CLOSE, np.ones((20, 20), np.uint8))
closed_mask_blue = cv2.morphologyEx(mask_blue, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
closed_mask_yellow = cv2.morphologyEx(mask_yellow, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
closed_mask_brown = cv2.morphologyEx(mask_brown, cv2.MORPH_CLOSE, np.ones((20, 20), np.uint8))
closed_mask_pink = cv2.morphologyEx(mask_pink, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
closed_mask_white = cv2.morphologyEx(mask_white, cv2.MORPH_CLOSE, np.ones((10, 10), np.uint8))
closed_mask_black = cv2.morphologyEx(mask_black, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
closed_mask_dark_blue = cv2.morphologyEx(mask_dark_blue, cv2.MORPH_CLOSE, np.ones((50, 50), np.uint8))
closed_mask_purple = cv2.morphologyEx(mask_purple, cv2.MORPH_CLOSE, np.ones((0, 0), np.uint8))
#display_image(mask_red)

# Find contours on the binary masks
contours_green, _ = cv2.findContours(closed_mask_green, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_red, _ = cv2.findContours(closed_mask_red, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_blue, _ = cv2.findContours(closed_mask_blue, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_yellow, _ = cv2.findContours(closed_mask_yellow, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_brown, _ = cv2.findContours(closed_mask_brown, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_pink, _ = cv2.findContours(closed_mask_pink, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_white, _ = cv2.findContours(closed_mask_white, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_black, _ = cv2.findContours(closed_mask_black, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_dark_blue, _ = cv2.findContours(closed_mask_dark_blue, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
contours_purple, _ = cv2.findContours(closed_mask_purple, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

# Specify a minimum and maximum area and width to identify objects
min_object_area = 300  # Minimum area
max_object_area = 6050  # Maximum area
max_object_width = 100  # Maximum width allowed for objects

# Initialize a copy of the original image for marking objects
marked_image = img.copy()

# Process contours for green color
objects_count_green = 0
for contour in contours_green:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_green += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (0, 255, 0), 2)
        cv2.putText(marked_image, f"Bulbasaur {objects_count_green}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

# Process contours for red color
objects_count_red = 0
for contour in contours_red:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_red += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (0, 0, 255), 2)
        cv2.putText(marked_image, f"Charmander {objects_count_red}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 2)


# Process contours for blue color
objects_count_blue = 0
for contour in contours_blue:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_blue += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (255, 240, 0), 2)
        cv2.putText(marked_image, f"Squirtle {objects_count_blue}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 240, 0), 2)

# Process contours for yellow color
objects_count_yellow = 0
for contour in contours_yellow:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_yellow += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (0, 255, 255), 2)
        cv2.putText(marked_image, f"Pikachu {objects_count_yellow}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 2)

# Process contours for brown color (Eevee)
objects_count_brown = 0
for contour in contours_brown:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_brown += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (80, 116, 155), 2)  # Assuming brown as (70, 70, 70)
        cv2.putText(marked_image, f"Eevee {objects_count_brown}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (80, 116, 155), 2)

# Process contours for pink color (Jigglypuff)
objects_count_pink = 0
for contour in contours_pink:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_pink += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (255, 0, 255), 2)  # Assuming pink as (255, 0, 255)
        cv2.putText(marked_image, f"Jigglypuff {objects_count_pink}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 255), 2)

# Process contours for white color (Machamp)
objects_count_white = 0
for contour in contours_white:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_white += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (145, 135, 115), 2)  # Assuming white as (255, 255, 255)
        cv2.putText(marked_image, f"Machamp {objects_count_white}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (145, 135, 115), 2)

# Process contours for black color (Umbreon)
objects_count_black = 0
for contour in contours_black:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_black += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (0, 0, 0), 2)  # Assuming black as (0, 0, 0)
        cv2.putText(marked_image, f"Umbreon {objects_count_black}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 2)

# Process contours for dark blue color (Snorlax)
objects_count_dark_blue = 0
for contour in contours_dark_blue:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_dark_blue += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (255, 0, 0), 2)  # Assuming dark blue as (0, 0, 128)
        cv2.putText(marked_image, f"Snorlax {objects_count_dark_blue}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 0, 0), 2)

# Process contours for purple color (Jynx)
objects_count_purple = 0
for contour in contours_purple:
    area = cv2.contourArea(contour)
    x, y, w, h = cv2.boundingRect(contour)

    if min_object_area < area < max_object_area and w < max_object_width:
        objects_count_purple += 1
        cv2.rectangle(marked_image, (x, y), (x + w, y + h), (128, 0, 128), 2)  # Assuming purple as (128, 0, 128)
        cv2.putText(marked_image, f"Jynx {objects_count_purple}", (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (128, 0, 128), 2)

# Show the marked image with all identified objects and print the counts
print(f"Number of identified Bulbasaur's objects: {objects_count_green}")
print(f"Number of identified Charmander's objects: {objects_count_red}")
print(f"Number of identified Squirtle's objects: {objects_count_blue}")
print(f"Number of identified Pikachu's objects: {objects_count_yellow}")
print(f"Number of identified Eevee's objects: {objects_count_brown}")
print(f"Number of identified Jigglypuff's objects: {objects_count_pink}")
print(f"Number of identified Machamp's objects: {objects_count_white}")
print(f"Number of identified Umbreon's objects: {objects_count_black}")
print(f"Number of identified Snorlax's objects: {objects_count_dark_blue}")
print(f"Number of identified Jynx's objects: {objects_count_purple}")
display_image(marked_image)


