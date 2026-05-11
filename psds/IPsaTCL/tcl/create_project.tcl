# ===========================================
# KORAK 1: Podešavanje direktorijuma
# ===========================================
set projName my_ip_project
set resultDir ../result/$projName
set releaseDir ../release/$projName

file mkdir $resultDir
file mkdir $releaseDir

# ===========================================
# KORAK 2: Kreiranje Vivado projekta
# ===========================================
create_project $projName $resultDir -part xc7z010clg400-1 -force
set_property target_language VHDL [current_project]

# ===========================================
# KORAK 3: Dodavanje VHDL fajlova
# ===========================================
set vhdl_files [list \
  "../vhdl/control_path.vhd" \
  "../vhdl/dual_port_bram.vhd" \
  "../vhdl/memory_subsystem.vhd" \
  "../vhdl/myip_v1_0.vhd" \
  "../vhdl/myip_v1_0_S00_AXI.vhd" \
]
add_files -norecurse $vhdl_files
update_compile_order -fileset sources_1

# Postavi top-level entitet
set_property top myip_v1_0 [current_fileset]

# Pokreni sintezu da se izgradi hijerarhija (neophodno za IPX)
launch_runs synth_1 -jobs 4
wait_on_run synth_1

# ===========================================
# KORAK 4: IP PACKAGING
# ===========================================
ipx::package_project -force $resultDir/$projName.srcs/sources_1/imports/myip_v1_0 \
  -root_dir $releaseDir \
  -vendor user.org -library user -taxonomy /UserIP

set core [ipx::current_core]

# Postavi IP metapodatke
set_property vendor FTN $core
set_property name myip_v1_0 $core
set_property display_name "myip_v1.0" $core
set_property description {Custom AXI4-Lite IP for image processing} $core
set_property company_url http://www.ftn.uns.ac.rs $core
set_property vendor_display_name FTN $core
set_property taxonomy {/Embedded_Processing/AXI_Peripheral /UserIP} $core
set_property supported_families {zynq Production} $core

# Automatsko prepoznavanje interfejsa (uključuje S00_AXI)
ipx::infer_bus_interfaces $core

# Uskladi portove i fajlove sa projektom
ipx::merge_project_changes files $core
ipx::merge_project_changes ports $core

# Validacija i čuvanje IP jezgra
ipx::update_checksums $core
ipx::check_integrity $core
set_property core_revision 1 $core
ipx::save_core $core

# Generiši XGUI i arhivu
ipx::update_source_project_archive -component $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::check_integrity $core

# (Opcionalno) Dodaj IP repozitorijum i osveži katalog
set_property ip_repo_paths "$releaseDir" [current_project]
update_ip_catalog
