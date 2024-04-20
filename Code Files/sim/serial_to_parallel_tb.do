vcom C:/Users/yuval/OneDrive/programming/VHDL/Project/src/serial_to_parallel.vhd
vcom C:/Users/yuval/OneDrive/programming/VHDL/Project/src/serial_to_parallel_tb.vhd

vsim serial_to_parallel_tb

restart -f

add wave -group serial_to_parallel_tb serial_to_parallel_tb/*
add wave -group serial_to_parallel serial_to_parallel_tb/DUT/*

run -all