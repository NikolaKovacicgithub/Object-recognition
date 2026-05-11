#ifndef INTERCONNECT_HPP
#define INTERCONNECT_HPP

#include <systemc>
#include <tlm>
#include <tlm_utils/simple_target_socket.h>
#include <tlm_utils/simple_initiator_socket.h>

// Interconnect modul koji prosleđuje transakcije od CPU-a do IP-a ili BRAM-a
class Interconnect : public sc_core::sc_module {
public:
    // Sockets za povezivanje sa CPU-om, IP-om i BRAM-om
    tlm_utils::simple_target_socket<Interconnect> cpu_socket;
    tlm_utils::simple_initiator_socket<Interconnect> bram_socket;
    tlm_utils::simple_initiator_socket<Interconnect> ip_socket;

    // Konstruktor: registruje b_transport metode sa target soketima
    SC_CTOR(Interconnect) 
        : cpu_socket("cpu_socket")
        , bram_socket("bram_socket")
        , ip_socket("ip_socket")
    {
        cpu_socket.register_b_transport(this, &Interconnect::cpu_b_transport);
    }

private:
    // Metoda za obradu dolaznih transakcija od CPU-a
    void cpu_b_transport(tlm::tlm_generic_payload& trans, sc_core::sc_time& delay);
};

#endif // INTERCONNECT_HPP
