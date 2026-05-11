#include <systemc>
#include <iostream>
#include <opencv2/opencv.hpp>
#include <stack>
#include <vector>

using namespace sc_core;
using namespace sc_dt; // For sc_int

SC_MODULE(ImageProcessingModule) {
    sc_fifo_in<cv::Mat> image_in;
    sc_fifo_out<cv::Mat> marked_image_out;

    void processColorContours(const cv::Mat& img, const cv::Scalar& lower, const cv::Scalar& upper, const cv::Scalar& color, const std::string& label, sc_int<16>& objects_count, cv::Mat& marked_image) {
        cv::Mat mask = cv::Mat::zeros(img.size(), CV_8UC1);

        for (sc_int<16> y = 0; y < img.rows; ++y) {
            for (sc_int<16> x = 0; x < img.cols; ++x) {
                cv::Scalar pixel = img.at<cv::Vec3b>(y, x);
                if (pixel[0] >= lower[0] && pixel[1] >= lower[1] && pixel[2] >= lower[2] &&
                    pixel[0] <= upper[0] && pixel[1] <= upper[1] && pixel[2] <= upper[2]) {
                    mask.at<uchar>(y, x) = 255;
                }
            }
        }

        cv::Mat closed_mask = mask.clone();

        for (sc_int<16> y = 0; y < closed_mask.rows; ++y) {
            for (sc_int<16> x = 0; x < closed_mask.cols; ++x) {
                if (mask.at<uchar>(y, x) == 255) {
                    for (sc_int<16> i = -5; i <= 5; ++i) {
                        for (sc_int<16> j = -5; j <= 5; ++j) {
                            sc_int<16> newY = y + i;
                            sc_int<16> newX = x + j;
                            if (newY >= 0 && newY < closed_mask.rows && newX >= 0 && newX < closed_mask.cols) {
                                closed_mask.at<uchar>(newY, newX) = 255;
                            }
                        }
                    }
                }
            }
        }

        cv::Mat temp_mask = closed_mask.clone();
        for (sc_int<16> y = 0; y < closed_mask.rows; ++y) {
            for (sc_int<16> x = 0; x < closed_mask.cols; ++x) {
                if (closed_mask.at<uchar>(y, x) == 255) {
                    bool allWhite = true;
                    for (sc_int<16> i = -5; i <= 5; ++i) {
                        for (sc_int<16> j = -5; j <= 5; ++j) {
                            sc_int<16> newY = y + i;
                            sc_int<16> newX = x + j;
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
                    closed_mask.at<uchar>(y, x) = allWhite ? 255 : 0;
                }
            }
        }

        std::vector<std::vector<cv::Point>> contours;
        contours.clear();
        cv::Mat visited = cv::Mat::zeros(closed_mask.size(), CV_8U);
        static const sc_int<8> dx[] = {1, 1, 0, -1, -1, -1, 0, 1};
        static const sc_int<8> dy[] = {0, 1, 1, 1, 0, -1, -1, -1};

        for (sc_int<16> y = 0; y < closed_mask.rows; ++y) {
            for (sc_int<16> x = 0; x < closed_mask.cols; ++x) {
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
                            for (sc_int<16> i = 0; i < 8; ++i) {
                                sc_int<16> newX = current.x + dx[i];
                                sc_int<16> newY = current.y + dy[i];
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

        sc_int<16> min_object_area = 60;
        sc_int<16> max_object_area = 6000;
        sc_int<16> max_object_width = 600;

        for (const auto& contour : contours) {
            double area = cv::contourArea(contour);
            cv::Rect rect = cv::boundingRect(contour);

            if (area > min_object_area && area < max_object_area && rect.width < max_object_width) {
                objects_count++;
                cv::rectangle(marked_image, rect, color, 2);
                cv::putText(marked_image, label + " " + std::to_string(objects_count), cv::Point(rect.x, rect.y - 10), cv::FONT_HERSHEY_SIMPLEX, 0.5, color, 2);
            }
        }
    }

    void display_and_count_objects() {
        cv::Mat img;
        sc_int<16> objects_count_green = 0, objects_count_red = 0, objects_count_blue = 0;
        sc_int<16> objects_count_yellow = 0, objects_count_brown = 0, objects_count_pink = 0;
        sc_int<16> objects_count_white = 0, objects_count_black = 0, objects_count_dark_blue = 0;
        sc_int<16> objects_count_purple = 0;


        
         while (true) {
            std::cout << "Waiting for the image..." << std::endl;
            img = image_in.read();
            std::cout << "Image received." << std::endl;
            if (img.empty()) {
                std::cerr << "Error: Image is empty!" << std::endl;
                break;
            }

            cv::Mat marked_image = img.clone();

            processColorContours(img, cv::Scalar(50, 90, 180), cv::Scalar(60, 130, 255), cv::Scalar(0, 0, 255), "Charmander", objects_count_red, marked_image);
            processColorContours(img, cv::Scalar(160, 145, 94), cv::Scalar(205, 190, 134), cv::Scalar(255, 0, 0), "Squirtle", objects_count_blue, marked_image);
            processColorContours(img, cv::Scalar(100, 135, 80), cv::Scalar(135, 200, 140), cv::Scalar(0, 255, 0), "Bulbasaur", objects_count_green, marked_image);
            processColorContours(img, cv::Scalar(120, 210, 240), cv::Scalar(180, 230, 250), cv::Scalar(0, 255, 255), "Pikachu", objects_count_yellow, marked_image);
            processColorContours(img, cv::Scalar(80, 116, 155), cv::Scalar(90, 150, 205), cv::Scalar(0, 75, 150), "Eevee", objects_count_brown, marked_image);
            processColorContours(img, cv::Scalar(190, 170, 220), cv::Scalar(220, 210, 255), cv::Scalar(255, 0, 255), "Jigglypuff", objects_count_pink, marked_image);
            processColorContours(img, cv::Scalar(150, 140, 130), cv::Scalar(190, 170, 150), cv::Scalar(255, 255, 255), "Machamp", objects_count_white, marked_image);
            processColorContours(img, cv::Scalar(65, 63, 58), cv::Scalar(85, 85, 77), cv::Scalar(0, 0, 0), "Umbreon", objects_count_black, marked_image);
            processColorContours(img, cv::Scalar(170, 180, 200), cv::Scalar(215, 230, 240), cv::Scalar(255, 0, 0), "Snorlax", objects_count_dark_blue, marked_image);
            processColorContours(img, cv::Scalar(80, 80, 140), cv::Scalar(105, 105, 225), cv::Scalar(128, 0, 128), "Jynx", objects_count_purple, marked_image);

            marked_image_out.write(marked_image);
            
        std::cout << "Number of identified Bulbasaur objects: " << objects_count_green << std::endl;
        std::cout << "Number of identified Charmander objects: " << objects_count_red << std::endl;
        std::cout << "Number of identified Squirtle objects: " << objects_count_blue << std::endl;
        std::cout << "Number of identified Pikachu objects: " << objects_count_yellow << std::endl;
        std::cout << "Number of identified Eevee objects: " << objects_count_brown << std::endl;
        std::cout << "Number of identified Jigglypuff objects: " << objects_count_pink << std::endl;
        std::cout << "Number of identified Machamp objects: " << objects_count_white << std::endl;
        std::cout << "Number of identified Umbreon objects: " << objects_count_black << std::endl;
        std::cout << "Number of identified Snorlax objects: " << objects_count_dark_blue << std::endl;
        std::cout << "Number of identified Jynx objects: " << objects_count_purple << std::endl;
        }
	    
    }

    SC_CTOR(ImageProcessingModule) {
        SC_THREAD(display_and_count_objects);
    }
};

int sc_main(int argc, char* argv[]) {
    sc_fifo<cv::Mat> img_fifo;
    sc_fifo<cv::Mat> marked_img_fifo;

    ImageProcessingModule imageProcessingModule("ImageProcessingModule");
    imageProcessingModule.image_in(img_fifo);
    imageProcessingModule.marked_image_out(marked_img_fifo);

    std::string imagePath = "/home/nikola/Desktop/proj/y24-g07/Data/slika.jpg";
    cv::Mat img = cv::imread(imagePath);

    if (img.empty()) {
        std::cerr << "Error: Image not found or unable to load from path: " << imagePath << std::endl;
        return -1;
    }
    
    

    img_fifo.write(img);

    sc_start();

    cv::Mat marked_img = marked_img_fifo.read();
    cv::imshow("Marked Image", marked_img);
    cv::waitKey(0);
   

    return 0;
}

