#include "interconnect.hpp"

void Interconnect::cpu_b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay) {
    if (trans.get_data_length() == 0) {
        ip_socket->b_transport(trans, delay); // Prosledi u IP
    } else {
        bram_socket->b_transport(trans, delay); // Prosledi u BRAM
    }
}
