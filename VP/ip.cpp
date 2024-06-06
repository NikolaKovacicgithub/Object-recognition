#include "ip.hpp"
#include <iostream>
#include <opencv2/opencv.hpp>
#include <stack>
#include <vector>

void IP::b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay) {
    if (trans.get_command() == tlm::TLM_WRITE_COMMAND) {
        std::cout << "IP module received write command, notifying event." << std::endl;
        start_processing_event.notify(sc_core::SC_ZERO_TIME); // Start SC_THREAD
        trans.set_response_status(tlm::TLM_OK_RESPONSE);
    } else {
        trans.set_response_status(tlm::TLM_COMMAND_ERROR_RESPONSE);
    }
}

void IP::run() {
    std::cout << "IP module SC_THREAD run function started." << std::endl;
    while (true) {
        wait(start_processing_event); // ceka se event
        std::cout << "Event received, starting image processing." << std::endl;

        cv::Mat img(img_height, img_width, CV_8UC3); // velicina slike
        std::cout << "Starting image read from BRAM." << std::endl;
        read_image_from_bram(img);
        std::cout << "Image read from BRAM complete." << std::endl;

        std::cout << "Starting image processing." << std::endl;
        processImage(img);
        std::cout << "Image processing complete." << std::endl;

        std::cout << "Starting image write to BRAM." << std::endl;
        write_image_to_bram(img);
        std::cout << "Image write to BRAM complete." << std::endl;
    }
}

void IP::read_image_from_bram(cv::Mat& img) {
    std::cout << "Reading image from BRAM." << std::endl;
    for (int i = 0; i < img.rows; ++i) {
        for (int j = 0; j < img.cols; ++j) {
            Message msg;

            tlm::tlm_generic_payload trans;
            sc_core::sc_time delay = sc_core::SC_ZERO_TIME;

            trans.set_command(tlm::TLM_READ_COMMAND);
            trans.set_address((i * img.cols + j) * sizeof(msg.data));
            trans.set_data_ptr(reinterpret_cast<unsigned char*>(&msg));
            trans.set_data_length(sizeof(Message));

            addr_b.write((i * img.cols + j) * sizeof(msg.data));
            en_b.write(true);
            we_b.write(false);

            wait(clk_b.posedge_event());

            msg.data[0] = dout_b[0];
            msg.data[1] = dout_b[1];
            msg.data[2] = dout_b[2];

            img.at<cv::Vec3b>(i, j) = cv::Vec3b(msg.data[0], msg.data[1], msg.data[2]);
        }
    }
    std::cout << "Image read from BRAM." << std::endl;
}

void IP::processImage(cv::Mat& img) {
    std::cout << "Processing image." << std::endl;
    cv::Mat marked_image = img.clone();
    objects_count_red = objects_count_blue = objects_count_green = 0;
    objects_count_yellow = objects_count_brown = objects_count_pink = 0;
    objects_count_white = objects_count_black = objects_count_dark_blue = 0;
    objects_count_purple = 0;

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

    std::cout << "Processed Image." << std::endl;
    img = marked_image;
}

void IP::processColorContours(const cv::Mat& img, const cv::Scalar& lower, const cv::Scalar& upper, const cv::Scalar& color, const std::string& label, int& objects_count, cv::Mat& marked_image) {
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

    cv::Mat closed_mask = mask.clone();

    for (int y = 0; y < closed_mask.rows; ++y) {
        for (int x = 0; x < closed_mask.cols; ++x) {
            if (mask.at<uchar>(y, x) == 255) {
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

    cv::Mat temp_mask = closed_mask.clone();
    for (int y = 0; y < closed_mask.rows; ++y) {
        for (int x = 0; x < closed_mask.cols; ++x) {
            if (closed_mask.at<uchar>(y, x) == 255) {
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
                closed_mask.at<uchar>(y, x) = allWhite ? 255 : 0;
            }
        }
    }

    std::vector<std::vector<cv::Point>> contours;
    contours.clear();
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

    int min_object_area = 60;
    int max_object_area = 6000;
    int max_object_width = 600;

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

void IP::write_image_to_bram(const cv::Mat& img) {
    std::cout << "Writing image to BRAM." << std::endl;
    for (int i = 0; i < img.rows; ++i) {
        for (int j = 0; j < img.cols; ++j) {
            Message msg;
            cv::Vec3b pixel = img.at<cv::Vec3b>(i, j);

            msg.data[0] = pixel[0];
            msg.data[1] = pixel[1];
            msg.data[2] = pixel[2];

            addr_b.write((i * img.cols + j) * sizeof(msg.data));
            din_b[0].write(msg.data[0]);
            din_b[1].write(msg.data[1]);
            din_b[2].write(msg.data[2]);
            we_b.write(true);
            en_b.write(true);

            wait(clk_b.posedge_event());

            en_b.write(false);
        }
    }
    std::cout << "Image written to BRAM." << std::endl;
}
