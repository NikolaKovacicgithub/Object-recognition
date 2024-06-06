#include <iostream>
#include <opencv4/opencv2/opencv.hpp>

cv::Mat load_image(const std::string& path) {
    return cv::imread(path, cv::IMREAD_COLOR);
}

void processColorContours(const cv::Mat& img, const cv::Scalar& lower, const cv::Scalar& upper, const cv::Scalar& color, const std::string& label, int& objects_count, cv::Mat& marked_image) {
    // Step 1: Color thresholding
    cv::Mat mask, closed_mask;
    cv::inRange(img, lower, upper, mask);
    
    // Step 2: Morphological closing operation
    cv::morphologyEx(mask, closed_mask, cv::MORPH_CLOSE, cv::getStructuringElement(cv::MORPH_RECT, cv::Size(10, 10)));
    
    // Step 3: Find contours in the closed mask
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(closed_mask, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Step 4: Parameters for object filtering
    int min_object_area = 300;
    int max_object_area = 6050;
    int max_object_width = 100;
    
    // Step 5: Process each contour
    for (const auto& contour : contours) {
    	// Calculate contour area and bounding rectangle
        double area = cv::contourArea(contour);
        cv::Rect rect = cv::boundingRect(contour);
        
	// Step 6: Object filtering based on area and width
        if (area > min_object_area && area < max_object_area && rect.width < max_object_width) {
            // Increment object count
            objects_count++;
            // Step 7: Draw rectangle around the object
            cv::rectangle(marked_image, rect, color, 2);
            // Step 8: Add label with object count
            cv::putText(marked_image, label + " " + std::to_string(objects_count), cv::Point(rect.x, rect.y - 10), cv::FONT_HERSHEY_SIMPLEX, 0.5, color, 2);
        }
    }
}



void display_and_count_objects(const cv::Mat& img) {
    cv::Mat marked_image = img.clone();
    cv::Mat mask;

    int objects_count_green = 0, objects_count_red = 0, objects_count_blue = 0;
    int objects_count_yellow = 0, objects_count_brown = 0, objects_count_pink = 0;
    int objects_count_white = 0, objects_count_black = 0, objects_count_dark_blue = 0;
    int objects_count_purple = 0;

// Adjusted color Scalar definitions for "Eevee" and "Snorlax"
    cv::Scalar greenColor(100, 135, 80);
    cv::Scalar redColor(45, 100, 200);
    cv::Scalar blueColor(175, 155, 100);
    cv::Scalar yellowColor(90, 110, 215);
    cv::Scalar brownColorLower(81, 126, 171); // Adjusted 10% reduction in lower range values for Eevee
    cv::Scalar brownColorUpper(126, 176, 220); // Adjusted 10% increase in upper range values for Eevee
    cv::Scalar pinkColor(190, 170, 220);
    cv::Scalar whiteColor(150, 140, 130);
    cv::Scalar blackColor(60, 60, 60);
    cv::Scalar darkBlueColor(100, 80, 0);
    cv::Scalar purpleColor(80, 80, 140);

    // Process contours with adjusted color ranges for "Eevee" and "Snorlax"
    processColorContours(img, cv::Scalar(100, 135, 80), cv::Scalar(135, 200, 140), greenColor, "Bulbasaur", objects_count_green, marked_image);
    processColorContours(img, cv::Scalar(45, 100, 200), cv::Scalar(60, 130, 255), redColor, "Charmander", objects_count_red, marked_image);
    processColorContours(img, cv::Scalar(175, 155, 100), cv::Scalar(220, 210, 142), blueColor, "Squirtle", objects_count_blue, marked_image);
    processColorContours(img, cv::Scalar(90, 110, 215), cv::Scalar(125, 215, 245), yellowColor, "Pikachu", objects_count_yellow, marked_image);
    processColorContours(img, brownColorLower, brownColorUpper, cv::Scalar(80, 116, 155), "Eevee", objects_count_brown, marked_image); // Adjusted range for Eevee	
    processColorContours(img, cv::Scalar(190, 170, 220), cv::Scalar(220, 210, 255), pinkColor, "Jigglypuff", objects_count_pink, marked_image);
    processColorContours(img, cv::Scalar(150, 140, 130), cv::Scalar(190, 170, 150), whiteColor, "Machamp", objects_count_white, marked_image);
    processColorContours(img, cv::Scalar(60, 60, 60), cv::Scalar(80, 80, 80), blackColor, "Umbreon", objects_count_black, marked_image);
    processColorContours(img, cv::Scalar(90, 72, 0), cv::Scalar(165, 132, 66), darkBlueColor, "Snorlax", objects_count_dark_blue, marked_image); // Adjusted range for Snorlax
    processColorContours(img, cv::Scalar(80, 80, 140), cv::Scalar(105, 105, 225), purpleColor, "Jynx", objects_count_purple, marked_image);
    
    
    // Print the counts for each identified object
    std::cout << "Number of identified Bulbasaur objects: " << objects_count_green << std::endl;
    std::cout << "Number of identified Charmander objects: " << objects_count_red << std::endl;
    std::cout << "Number of identified Squirtle objects: " << objects_count_blue << std::endl;
    std::cout << "Number of identified Pikachu objects: " << objects_count_yellow << std::endl;
    std::cout << "Number of identified Eevee objects: " << objects_count_brown << std::endl;
    std::cout << "Number of identified Jiglypuff objects: " << objects_count_pink << std::endl;
    std::cout << "Number of identified Machamp objects: " << objects_count_white << std::endl;
    std::cout << "Number of identified Umbreon objects: " << objects_count_black << std::endl;
    std::cout << "Number of identified Snorlax objects: " << objects_count_dark_blue << std::endl;
    std::cout << "Number of identified Jynx objects: " << objects_count_purple << std::endl;

    // Show the marked image with identified objects and print the counts
    cv::imshow("Marked Image", marked_image);

    // Display masks for Eevee and Snorlax
    cv::inRange(img, brownColorLower, brownColorUpper, mask);
    cv::imshow("Eevee Mask", mask);

    //cv::inRange(img, cv::Scalar(100, 80, 0), cv::Scalar(150, 120, 60), mask); // Range for Snorlax
    //cv::imshow("Snorlax Mask", mask);

    cv::waitKey(0);
}


int main() {
    std::string imagePath = "/home/nikola/Desktop/pr/y24-g07/Data/picture_24.jpg";
    cv::Mat img = load_image(imagePath);
    
    if (img.empty()) {
        std::cerr << "Error: Image not found or unable to load from path: " << imagePath << std::endl;
        return -1;
    }
    
  int objects_count_green = 0, objects_count_red = 0, objects_count_blue = 0;
    int objects_count_yellow = 0, objects_count_brown = 0, objects_count_pink = 0;
    int objects_count_white = 0, objects_count_black = 0, objects_count_dark_blue = 0;
    int objects_count_purple = 0;

    display_and_count_objects(img);

    return 0;
}

