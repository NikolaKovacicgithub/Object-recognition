#include "bram.hpp"
#include <cstring>
#include <iostream>

void BRAM::b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay) {
    tlm::tlm_command cmd = trans.get_command();
    sc_dt::uint64 addr = trans.get_address();
    unsigned char* ptr = trans.get_data_ptr();
    unsigned int len = trans.get_data_length();

    // Provera opsega adrese
    if (addr + len > sizeof(memory)) {
        trans.set_response_status(tlm::TLM_ADDRESS_ERROR_RESPONSE);
        return;
    }

    // Obrada komande za čitanje i pisanje
    if (cmd == tlm::TLM_READ_COMMAND) {
        std::memcpy(ptr, memory + addr, len);
    } else if (cmd == tlm::TLM_WRITE_COMMAND) {
        std::memcpy(memory + addr, ptr, len);
    }

    trans.set_response_status(tlm::TLM_OK_RESPONSE);
}

void BRAM::wire_b_transport() {
    if (en_b.read()) {
        auto addr = addr_b.read();
        if (addr < sizeof(memory)) {
            if (we_b.read()) {
                memory[addr] = din_b[0].read();
                memory[addr + 1] = din_b[1].read();
                memory[addr + 2] = din_b[2].read();
            } else {
                dout_b[0].write(memory[addr]);
                dout_b[1].write(memory[addr + 1]);
                dout_b[2].write(memory[addr + 2]);
            }
        }
    }
}

// Ispis sadržaja BRAM memorije radi provere
void BRAM::print_memory_contents() {
    std::cout << "BRAM memory contents: ";
    for (size_t i = 0; i < 100; ++i) {
        std::cout << std::hex << static_cast<int>(memory[i]) << " ";
    }
    std::cout << std::dec << std::endl;
}

// Pisanje sadržaja BRAM memorije u fajl u decimalnom formatu
void BRAM::write_memory_to_file(const std::string& filename) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: Could not open file for writing." << std::endl;
        return;
    }

    size_t image_size = img_height * img_width * 3;
    for (size_t i = 0; i < image_size; ++i) {
        file << static_cast<int>(memory[i]) << " ";
        if ((i + 1) % 16 == 0) {
            file << "\n";
        }
    }
    file.close();

    std::cout << "BRAM memory written to file: " << filename << std::endl;
}

// Pisanje sadržaja procesirane BRAM memorije u fajl u decimalnom formatu
void BRAM::write_processed_memory_to_file(const std::string& filename) {
    std::ofstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error: Could not open file for writing." << std::endl;
        return;
    }

    size_t image_size = img_height * img_width * 3;
    for (size_t i = 0; i < image_size; ++i) {
        file << static_cast<int>(memory[i]) << " ";
        if ((i + 1) % 16 == 0) {
            file << "\n";
        }
    }
    file.close();

    std::cout << "Processed BRAM memory written to file: " << filename << std::endl;
}
