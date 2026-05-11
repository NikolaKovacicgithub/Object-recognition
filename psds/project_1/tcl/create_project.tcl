# KORAK 1: Podešavanje direktorijuma
set projName control_project
set resultDir ../result/$projName
set releaseDir ../release/$projName
file mkdir $resultDir
file mkdir $releaseDir

# Kreiranje projekta
create_project $projName $resultDir -part xc7z010clg400-1 -force

# Postavljanje jezika projekta i simulacije na VHDL
set_property target_language VHDL [current_project]
set_property simulator_language VHDL [current_project]

# KORAK 2: Dodavanje VHDL izvornih fajlova
add_files -norecurse ../vhdl/control_path.vhd
add_files -norecurse ../vhdl/dual_port_bram.vhd
add_files -norecurse ../vhdl/memory_subsystem.vhd

# (Opciono) Dodavanje testbencha
add_files -fileset sim_1 ../vhdl/control_path_tb.vhd

# Dodavanje XDC constraints fajla
add_files -fileset constrs_1 ../vhdl/constraints.xdc

# Ažuriranje redosleda kompilacije
update_compile_order -fileset sources_1

# KORAK 3: Sinteza
launch_runs synth_1
wait_on_run synth_1
puts "********************************************"
puts "*             Sinteza zavrsena!            *"
puts "********************************************"

# KORAK 4: Implementacija + generisanje bitstream-a
# Ako ne koristiš dodatnu pre_write_bitstream skriptu, ovu liniju možeš izbaciti
# set_property STEPS.WRITE_BITSTREAM.TCL.PRE [pwd]/pre_write_bitstream.tcl [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
puts "***********************************************"
puts "*          Implementacija zavrsena!           *"
puts "***********************************************"

# KORAK 5: Kopiranje bit fajla u release folder
file copy -force $resultDir/${projName}.runs/impl_1/${projName}.bit \
  $releaseDir/${projName}.bit
puts "***********************************************"
puts "*      Bitstream fajl kopiran u release       *"
puts "***********************************************"

# KORAK 6: Otvaranje Vivado GUI-ja sa projektom
start_gui