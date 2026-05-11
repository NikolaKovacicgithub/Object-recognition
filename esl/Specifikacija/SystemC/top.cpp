#include <systemc.h>
#include <iostream>

class ImageLoaderModule : public sc_module {
public:
    // Ports
    sc_in<bool> clk;
    sc_out<bool> rst;
    // Add more ports as needed

    // Constructor
    SC_CTOR(ImageLoaderModule) {
        SC_METHOD(loadImage);
        sensitive << clk.pos();
        // Add more sensitivity if needed

        // Initialization
        rst.initialize(true);
        SC_THREAD(resetThread);
    }

    // Load image method
    void loadImage() {
        if (rst.read()) {
            // Reset behavior
            // You may need to add more reset logic here
        } else {
            // Image loading behavior
            std::string imagePath = "/home/nikola/Desktop/pr/y24-g07/Data/picture_24.jpg";
            // Simulate the loading process
            std::cout << "Loading image from " << imagePath << std::endl;
            // You can add more simulation logic here
        }
    }

    // Reset thread
    void resetThread() {
        wait(1, SC_NS);
        rst.write(false);
    }
};

int sc_main(int argc, char* argv[]) {

    // Initialize SystemC kernel
    sc_initialize();

    // Instantiate module
    ImageLoaderModule imgLoader("ImageLoaderModule");

    // Add signals and other modules as needed

    // Start simulation
    sc_start();

    // Clean up
    sc_stop();
    return 0;
}

