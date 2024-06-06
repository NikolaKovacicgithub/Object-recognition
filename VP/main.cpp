#define SC_INCLUDE_DYNAMIC_PROCESSES

#include <systemc>
#include "cpu.hpp"
#include "interconnect.hpp"
#include "bram.hpp"
#include "ip.hpp"

int sc_main(int argc, char* argv[]) {
    if (argc < 6) {
        std::cerr << "Usage: " << argv[0] << " <img_height> <img_width> <input_image_path> <output_text_file> <processed_text_file>" << std::endl;
        return 1;
    }

    int img_height = std::stoi(argv[1]);
    int img_width = std::stoi(argv[2]);
    std::string input_image_path = argv[3];
    std::string output_text_file = argv[4];
    std::string processed_text_file = argv[5];

    CPU cpu("CPU");
    Interconnect interconnect("Interconnect");
    BRAM bram("BRAM");
    IP ip("IP");

    bram.img_height = img_height;
    bram.img_width = img_width;
    ip.img_height = img_height;
    ip.img_width = img_width;
    cpu.image_path = input_image_path;

    // Deklaracija sc_signala za komunikaciju preko žica
    sc_core::sc_signal<bool> en_b_signal("en_b_signal");
    sc_core::sc_signal<sc_dt::uint64> addr_b_signal("addr_b_signal");
    sc_core::sc_signal<unsigned char> din_b_signal[3];
    sc_core::sc_signal<unsigned char> dout_b_signal[3];
    sc_core::sc_signal<bool> reset_b_signal("reset_b_signal");
    sc_core::sc_signal<bool> we_b_signal("we_b_signal");
    sc_core::sc_clock clk_b_signal("clk_b_signal", 10, sc_core::SC_NS);

    // povezivanje cpu sa interconnect
    cpu.socket.bind(interconnect.cpu_socket);

    // povezivanje interconnect sa BRAM i IP
    interconnect.bram_socket.bind(bram.socket);
    interconnect.ip_socket.bind(ip.target_socket);

    // povezivanje signala izmedju IP i BRAM
    ip.en_b(en_b_signal);
    bram.en_b(en_b_signal);

    ip.addr_b(addr_b_signal);
    bram.addr_b(addr_b_signal);

    for (int i = 0; i < 3; ++i) {
        ip.din_b[i](din_b_signal[i]);
        bram.din_b[i](din_b_signal[i]);

        ip.dout_b[i](dout_b_signal[i]);
        bram.dout_b[i](dout_b_signal[i]);
    }

    ip.reset_b(reset_b_signal);
    bram.reset_b(reset_b_signal);

    ip.we_b(we_b_signal);
    bram.we_b(we_b_signal);

    ip.clk_b(clk_b_signal);
    bram.clk_b(clk_b_signal);

    sc_core::sc_start(1, sc_core::SC_SEC); // pokretanje simulacije

    bram.write_memory_to_file(output_text_file);

    cpu.trigger_ip_processing();

    sc_core::sc_start(1, sc_core::SC_SEC);

    bram.write_processed_memory_to_file(processed_text_file);

    // Ispis pronadjenih objekata
    std::cout << "Number of identified Bulbasaur objects: " << ip.objects_count_green << std::endl;
    std::cout << "Number of identified Charmander objects: " << ip.objects_count_red << std::endl;
    std::cout << "Number of identified Squirtle objects: " << ip.objects_count_blue << std::endl;
    std::cout << "Number of identified Pikachu objects: " << ip.objects_count_yellow << std::endl;
    std::cout << "Number of identified Eevee objects: " << ip.objects_count_brown << std::endl;
    std::cout << "Number of identified Jigglypuff objects: " << ip.objects_count_pink << std::endl;
    std::cout << "Number of identified Machamp objects: " << ip.objects_count_white << std::endl;
    std::cout << "Number of identified Umbreon objects: " << ip.objects_count_black << std::endl;
    std::cout << "Number of identified Snorlax objects: " << ip.objects_count_dark_blue << std::endl;
    std::cout << "Number of identified Jynx objects: " << ip.objects_count_purple << std::endl;

    return 0;
}
