#ifndef CPU_HPP
#define CPU_HPP

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_initiator_socket.h>
#include "message.hpp"
#include <opencv2/opencv.hpp>

class CPU : public sc_core::sc_module {
public:
    // Inicijator soket za slanje transakcija
    tlm_utils::simple_initiator_socket<CPU> socket;
    std::string image_path;

    SC_CTOR(CPU) {
        SC_THREAD(execute);
    }
    
    // Metoda za pokretanje IP procesiranja
    void trigger_ip_processing();

private:

    // Metoda za izvršavanje CPU operacija
    void execute();
    
    // Metoda za učitavanje podataka slike i slanje u BRAM
    void load_image_to_bram(const std::string& image_path);
};

#endif // CPU_HPP
