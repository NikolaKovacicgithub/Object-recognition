#include <iostream>
#include <opencv4/opencv2/opencv.hpp>
#include <stack>

cv::Mat load_image(const std::string& path) {
    return cv::imread(path, cv::IMREAD_COLOR);
}


void processColorContours(const cv::Mat& img, const cv::Scalar& lower, const cv::Scalar& upper, const cv::Scalar& color, const std::string& label, int& objects_count, cv::Mat& marked_image) {
    // Step 1: Color thresholding
    cv::Mat mask = cv::Mat::zeros(img.size(), CV_8UC1);
    for (int y = 0; y < img.rows; ++y) {
        for (int x = 0; x < img.cols; ++x) {
            cv::Scalar pixel = img.at<cv::Vec3b>(y, x);
            if (pixel[0] >= lower[0] && pixel[1] >= lower[1] && pixel[2] >= lower[2] &&
                pixel[0] <= upper[0] && pixel[1] <= upper[1] && pixel[2] <= upper[2]) {
                mask.at<uchar>(y, x) = 255;
            }
        }
    }

    // Alternative Morphological Closing Operation
    cv::Mat closed_mask = mask.clone();  // Clone the original mask

    // Dilation operation (expanding bright regions)
    for (int y = 0; y < closed_mask.rows; ++y) {
        for (int x = 0; x < closed_mask.cols; ++x) {
            if (mask.at<uchar>(y, x) == 255) {
                // Set pixels in the neighborhood to 255
                for (int i = -5; i <= 5; ++i) {
                    for (int j = -5; j <= 5; ++j) {
                        int newY = y + i;
                        int newX = x + j;
                        if (newY >= 0 && newY < closed_mask.rows && newX >= 0 && newX < closed_mask.cols) {
                            closed_mask.at<uchar>(newY, newX) = 255;
                        }
                    }
                }
            }
        }
    }

    // Erosion operation (shrinking bright regions)
    cv::Mat temp_mask = closed_mask.clone();  // Create a temporary mask to avoid modifying pixels during erosion
    for (int y = 0; y < closed_mask.rows; ++y) {
        for (int x = 0; x < closed_mask.cols; ++x) {
            if (closed_mask.at<uchar>(y, x) == 255) {
                // Check if all pixels in the neighborhood are 255
                bool allWhite = true;
                for (int i = -5; i <= 5; ++i) {
                    for (int j = -5; j <= 5; ++j) {
                        int newY = y + i;
                        int newX = x + j;
                        if (newY >= 0 && newY < closed_mask.rows && newX >= 0 && newX < closed_mask.cols) {
                            if (temp_mask.at<uchar>(newY, newX) != 255) {
                                allWhite = false;
                                break;
                            }
                        }
                    }
                    if (!allWhite) {
                        break;
                    }
                }
                // Set the pixel to 255 only if all pixels in the neighborhood are 255
                closed_mask.at<uchar>(y, x) = allWhite ? 255 : 0;
            }
        }
    }

    // Step 3: Find contours in the closed mask manually
 std::vector<std::vector<cv::Point>> contours;
    contours.clear();  // Clear the existing contours

    cv::Mat visited = cv::Mat::zeros(closed_mask.size(), CV_8U);

    static const int dx[] = {1, 1, 0, -1, -1, -1, 0, 1};
    static const int dy[] = {0, 1, 1, 1, 0, -1, -1, -1};

    for (int y = 0; y < closed_mask.rows; ++y) {
        for (int x = 0; x < closed_mask.cols; ++x) {
            if (closed_mask.at<uchar>(y, x) == 255 && visited.at<uchar>(y, x) == 0) {
                std::vector<cv::Point> contour;
                std::stack<cv::Point> stack;
                stack.push(cv::Point(x, y));

                while (!stack.empty()) {
                    cv::Point current = stack.top();
                    stack.pop();

                    if (visited.at<uchar>(current.y, current.x) == 0 && closed_mask.at<uchar>(current.y, current.x) == 255) {
                        visited.at<uchar>(current.y, current.x) = 255;
                        contour.push_back(current);

                        for (int i = 0; i < 8; ++i) {
                            int newX = current.x + dx[i];
                            int newY = current.y + dy[i];

                            if (newX >= 0 && newX < closed_mask.cols && newY >= 0 && newY < closed_mask.rows) {
                                stack.push(cv::Point(newX, newY));
                            }
                        }
                    }
                }
                contours.push_back(contour);
            }
        }
    }

    // Step 4: Parameters for object filtering
    int min_object_area = 120;
    int max_object_area = 6050;
    int max_object_width = 300;

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
    cv::Scalar redColor(50, 90, 180);
    cv::Scalar blueColor(160, 145, 98);
    cv::Scalar yellowColor(120, 210, 240);
    cv::Scalar brownColorLower(70, 110, 150); // Adjusted 10% reduction in lower range values for Eevee
    cv::Scalar brownColorUpper(90, 150, 205); // Adjusted 10% increase in upper range values for Eevee
    cv::Scalar pinkColor(190, 170, 220);
    cv::Scalar whiteColor(150, 140, 130);
    cv::Scalar blackColor(62, 52, 42);
    cv::Scalar darkBlueColor(100, 80, 0);
    cv::Scalar purpleColor(80, 80, 140);

    
    processColorContours(img, cv::Scalar(50, 90, 180), cv::Scalar(60, 130, 255), redColor, "Charmander", objects_count_red, marked_image);
    processColorContours(img, cv::Scalar(160, 145, 98), cv::Scalar(189, 169, 129), blueColor, "Squirtle", objects_count_blue, marked_image);
    processColorContours(img, cv::Scalar(100, 135, 80), cv::Scalar(135, 200, 140), greenColor, "Bulbasaur", objects_count_green, marked_image);
    processColorContours(img, cv::Scalar(120, 210, 240), cv::Scalar(180, 230, 250), yellowColor, "Pikachu", objects_count_yellow, marked_image);
    processColorContours(img, brownColorLower, brownColorUpper, cv::Scalar(80, 116, 155), "Eevee", objects_count_brown, marked_image); // Adjusted range for Eevee	
    processColorContours(img, cv::Scalar(190, 170, 220), cv::Scalar(220, 210, 255), pinkColor, "Jigglypuff", objects_count_pink, marked_image);
    processColorContours(img, cv::Scalar(150, 140, 130), cv::Scalar(190, 170, 150), whiteColor, "Machamp", objects_count_white, marked_image);
    processColorContours(img, cv::Scalar(65,63,58), cv::Scalar(85, 85, 77), blackColor, "Umbreon", objects_count_black, marked_image);
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
/*
    // Show the marked image with identified objects and print the counts
    cv::imshow("Marked Image", marked_image);
    
    // Display masks for Charmander
    cv::inRange(img, cv::Scalar(50, 90, 180), cv::Scalar(60, 130, 255), mask);
    cv::imshow("Charmander Mask", mask);
    
    // Display masks for Squirtle
    cv::inRange(img, cv::Scalar(160, 145, 98), cv::Scalar(189, 169, 129), mask);
    cv::imshow("Squirtle Mask", mask);
    
    // Display masks for Bulbasaur
    cv::inRange(img, cv::Scalar(100, 135, 80), cv::Scalar(135, 200, 140), mask);
    cv::imshow("Bulbasaur Mask", mask);
    
    // Display masks for Pikachu
    cv::inRange(img, cv::Scalar(120, 210, 240), cv::Scalar(180, 230, 250), mask);
    cv::imshow("Pikachu Mask", mask);
   
    // Display masks for Eevee
    cv::inRange(img, brownColorLower, brownColorUpper, mask);
    cv::imshow("Eevee Mask", mask);
    
    // Display masks for Jigglypuff
    cv::inRange(img, cv::Scalar(190, 170, 220), cv::Scalar(220, 210, 255), mask);
    cv::imshow("Jigglypuff Mask", mask);
    
    // Display masks for Machamp
    cv::inRange(img, cv::Scalar(150, 140, 130), cv::Scalar(190, 170, 150), mask);
    cv::imshow("Machamp Mask", mask);
    
    // Display masks for Umbreon
    cv::inRange(img, cv::Scalar(65,63,58), cv::Scalar(85, 85, 77), mask);
    cv::imshow("Umbreon mask", mask);
    
    // Display masks for Snorlax
    cv::inRange(img, cv::Scalar(90, 72, 0), cv::Scalar(165, 132, 66), mask);
    cv::imshow("Snorlax mask", mask);
    
    // Display masks for Jynx
    cv::inRange(img, cv::Scalar(80, 80, 140), cv::Scalar(105, 105, 225), mask);
    cv::imshow("Jynx mask", mask);
*/
    cv::waitKey(0);
}

int main() {
    std::string imagePath = "/home/nikola/Desktop/pr/y24-g07/Data/picture_24.jpg";
    cv::Mat img = load_image(imagePath);

    if (img.empty()) {
        std::cerr << "Error: Image not found or unable to load from path: " << imagePath << std::endl;
        return -1;
    }

    display_and_count_objects(img);

    return 0;
}

