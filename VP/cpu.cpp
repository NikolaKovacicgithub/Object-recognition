#include "cpu.hpp"
#include <iostream>
#include <opencv2/opencv.hpp>

void CPU::execute() {
    // ucitaj i posalji sliku u bram
    load_image_to_bram(image_path);
}

void CPU::load_image_to_bram(const std::string& image_path) {
    cv::Mat image = cv::imread(image_path, cv::IMREAD_COLOR);
    if (image.empty()) {
        std::cerr << "Error: Could not open or find the image at " << image_path << std::endl;
        return;
    }

    std::cout << "Loaded image from path: " << image_path << std::endl;

    for (int i = 0; i < image.rows; ++i) {
        for (int j = 0; j < image.cols; ++j) {
            Message msg;
            cv::Vec3b pixel = image.at<cv::Vec3b>(i, j);

            msg.data[0] = pixel[0]; // plava
            msg.data[1] = pixel[1]; // zelena
            msg.data[2] = pixel[2]; // crvena

            tlm::tlm_generic_payload trans;
            sc_core::sc_time delay = sc_core::SC_ZERO_TIME;

            trans.set_command(tlm::TLM_WRITE_COMMAND);
            trans.set_address((i * image.cols + j) * sizeof(msg.data)); // adresa od pozicije piksela
            trans.set_data_ptr(reinterpret_cast<unsigned char*>(&msg));
            trans.set_data_length(sizeof(Message));

            socket->b_transport(trans, delay);

            if (trans.is_response_error()) {
                std::cerr << "Error: Transaction failed at address " << (i * image.cols + j) << std::endl;
                return;
            }
        }
    }

    std::cout << "Image loaded into BRAM." << std::endl;
}

void CPU::trigger_ip_processing() {
    tlm::tlm_generic_payload trans;
    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;

    trans.set_command(tlm::TLM_WRITE_COMMAND);
    trans.set_address(0);
    trans.set_data_length(0);

    std::cout << "CPU: Sending trigger command to Interconnect for IP processing." << std::endl;
    socket->b_transport(trans, delay);

    if (trans.is_response_error()) {
        std::cerr << "Error: IP processing trigger failed." << std::endl;
    }
}
