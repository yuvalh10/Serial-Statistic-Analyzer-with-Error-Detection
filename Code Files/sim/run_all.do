do compile_all.do

vsim statistics_calc_tb

add wave -group serial_data_generator statistics_calc_tb/dut/serial_data_generator1/*
add wave -group serial_to_parallel statistics_calc_tb/dut/serial_to_parallel1/*
add wave -group main_controller statistics_calc_tb/dut/main_controller1/*
add wave -group statistics_calc statistics_calc_tb/dut/*
add wave -group statistics_calc_tb statistics_calc_tb/*
add wave -group sync_diff_start statistics_calc_tb/dut/start_sync/*

#radix statistics_calc/dut/serial_to_parallel1/* unsigned

run -all