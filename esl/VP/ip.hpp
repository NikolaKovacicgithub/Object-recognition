#ifndef IP_HPP
#define IP_HPP

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include <tlm_utils/simple_target_socket.h>
#include <opencv2/opencv.hpp>
#include "message.hpp"

class IP : public sc_core::sc_module {
public:
    tlm_utils::simple_target_socket<IP> target_socket;

    sc_core::sc_out<bool> en_b;
    sc_core::sc_out<sc_dt::uint64> addr_b;
    sc_core::sc_out<unsigned char> din_b[3];
    sc_core::sc_in<unsigned char> dout_b[3];
    sc_core::sc_out<bool> reset_b;
    sc_core::sc_out<bool> we_b;
    sc_core::sc_in<bool> clk_b;

    int img_height, img_width;

    int objects_count_red = 0, objects_count_blue = 0, objects_count_green = 0;
    int objects_count_yellow = 0, objects_count_brown = 0, objects_count_pink = 0;
    int objects_count_white = 0, objects_count_black = 0, objects_count_dark_blue = 0;
    int objects_count_purple = 0;

    SC_CTOR(IP) : target_socket("target_socket"), en_b("en_b"), addr_b("addr_b"), reset_b("reset_b"), we_b("we_b"), clk_b("clk_b") {
        SC_THREAD(run);
        target_socket.register_b_transport(this, &IP::b_transport);
    }

private:
    sc_core::sc_event start_processing_event;

    void b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay);
    void processImage(cv::Mat& img);
    void read_image_from_bram(cv::Mat& img);
    void write_image_to_bram(const cv::Mat& img);
    void processColorContours(const cv::Mat& img, const cv::Scalar& lower, const cv::Scalar& upper, const cv::Scalar& color, const std::string& label, int& objects_count, cv::Mat& marked_image);
    void run();
};

#endif // IP_HPP
