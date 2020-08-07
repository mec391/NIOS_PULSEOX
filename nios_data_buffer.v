module data_buffer(

//top module
input clk,

//fsm
input in_reset_n,

input [1:0] in_data_control,
output reg [1:0] out_diag_er,


//addr sel
input in_strm_dn,




//temporary data to fifo
output reg signed [21:0] led_one,   
output reg [21:0] aled_one,
output reg [21:0] led_one_aled_one,
output reg signed [21:0] led_two,
output reg [21:0] aled_two,
output reg [21:0] led_two_aled_two,

//updated final values out to fifo
output reg final_comp_complete,
output  [23:0] SPO2_out,
output  [23:0] HR_out,

//fpga cpu comm
output reg [13:0] out_er_data,

//alu


//calibration

//read ram
output reg [2:0] out_addr,
input [23:0] in_strm_data,


output reg new_samples,

//2/22/testing
output data_fromfft_buff,
output tx
	);

reg er;
reg diag_step;
reg [3:0] reg_counter;



always@(posedge clk)
begin

	if(~in_reset_n) 
	begin
		er <= 0;
		diag_step <= 0;
		reg_counter <= 0;
		out_addr <= 0;
		out_er_data <= 0;
		out_diag_er <= 0;
		led_one <= 0;
		aled_one <= 0;
		led_one_aled_one <= 0;
		led_two <= 0;
		aled_two <= 0;
		led_two_aled_two <= 0;
	end

else begin

	case(in_data_control)
		2'b00: //perform no action
			begin
		er <= 0;
		diag_step <= 0;
		reg_counter <= 0;
		out_addr <= 0;
		out_er_data <= 0;
		out_diag_er <= 0;
		led_one <= 0;
		aled_one <= 0;
		led_one_aled_one <= 0;
		led_two <= 0;
		aled_two <= 0;
		led_two_aled_two <= 0;
			end
		2'b01: //get diag info, process, send out
			begin
				if(~diag_step)
				begin
				out_addr <= 3'b110;
				out_er_data <= in_strm_data[13:0];
				er <= | in_strm_data[13:0];
				diag_step <= 1;
				end
				else 
				begin
					case(er)
						1'b0: //no errors
						begin
							out_diag_er <= 2'b10;
						end
						1'b1: //errors
							out_diag_er <= 2'b01;
					endcase
				end
			end
		2'b10: //perform streaming process
			begin
				case (reg_counter)
					4'b0000:
							begin
							new_samples <= 0;
							if(in_strm_dn)
							begin
								out_addr <= 0;
								led_two <= in_strm_data[21:0];
								reg_counter <= 4'b0001;
							end
							else begin
								out_addr <= 0;
								led_two <= led_two;
								reg_counter <= reg_counter;
							end
							end
					4'b0001: //delay
							begin
								out_addr <= 0;
								led_two <= in_strm_data[21:0];
								reg_counter <= 4'b0010;
								
							end
					4'b0010:
							begin
								out_addr <= 1;
								aled_two <= in_strm_data[21:0];
								reg_counter <= 4'b0011;
								//shift out of twos comp
								/*if(led_two[21] == 1)
									begin
										led_two[21] <= 0;
									end
								else
								begin
										led_two[21] <= 1;
								end
								*/
								 
							end
					4'b0011: //delay
							begin
								out_addr <= 1;
								aled_two <= in_strm_data[21:0];
								reg_counter <= 4'b0100;
							end
					4'b0100:
							begin
								out_addr <= 3'b010;
								led_one <= in_strm_data[21:0];
								reg_counter <= 4'b0101;
							end
					4'b0101: //delay
							begin
								out_addr <= 3'b010;
								led_one <= in_strm_data[21:0];
								reg_counter <= 4'b0110;
							end
					4'b0110:
							begin
								out_addr <= 3'b011;
								aled_one <= in_strm_data[21:0];
								reg_counter <= 4'b0111;
								//shift out of twos comp
								/*if (led_one[21] == 1)
									begin
										led_one[21] <= 0;
									end
									else begin
										led_one[21] <= 1;
									end
									*/
							end
					4'b0111: //delay
							begin
								out_addr <= 3'b011;
								aled_one <= in_strm_data[21:0];
								reg_counter <= 4'b1000;
							end

					4'b1000:
							begin
								out_addr <= 3'b100;
								led_two_aled_two <= in_strm_data[21:0];
								reg_counter <= 4'b1001;
							end
					4'b1001: //delay
							begin
								out_addr <= 3'b100;
								led_two_aled_two <= in_strm_data[21:0];
								reg_counter <= 4'b1010;
							end
					4'b1010:
							begin
								out_addr <= 3'b101;
								led_one_aled_one <= in_strm_data[21:0];
								reg_counter <= 4'b1011;
							end
					4'b1011:
							begin
								out_addr <= 3'b101;
								led_one_aled_one <= in_strm_data[21:0];
								reg_counter <= 4'b0000;
								new_samples <= 1;
							end

				endcase
			end



	endcase
	end
end

//AC and DC components
wire [23:0] led1_AC_computed;
wire [23:0] led1_DC_computed;
wire [23:0] led2_AC_computed;
wire [23:0] led2_DC_computed;
wire led1_new_data;
wire led2_new_data;

reg led1_reg;
reg led2_reg;
reg final_comp_dv;

//route hr, spo2 and final comp done to output regs to top moduel and fifo
wire [23:0] HR;
wire [23:0] SPO2;
wire final_comp_done;

wire td_new_data;

//testing dc and ac values
//assign HR_out = led1_DC_computed;
//assign SPO2_out = led1_AC_computed;



////////August 2020 Nios Mod


assign HR_out = HR;   //otuput data to fio
assign SPO2_out = SPO2; //output data to fifo
assign final_comp_complete =  ///put the dv for comp done here

/*
always@(posedge clk)
begin//Procedure to start final comp
	//Elaraby thinks data comp. time for both branches will take same amount
	if(led2_new_data)
		begin
			final_comp_dv <= 1;
		end
		else begin
			final_comp_dv <= 0;
		end

end

//procedure for final comp finish
always@(posedge clk)
begin
	if(final_comp_done)
		begin
			final_comp_complete <= 1;
		end
		else begin
			final_comp_complete <= 0;
		end
end


assign data_fromfft_buff = led2_new_data;

*/

/*
//need to isntantiate final comp module
final_comp fc0(
	.clk (clk),
	.reset_n (in_reset_n),
	.final_comp_dv (final_comp_dv),
	.led1_AC_computed (led1_AC_computed),
	.led1_DC_computed (led1_DC_computed),
	.led2_AC_computed (led2_AC_computed),
	.led2_DC_computed (led2_DC_computed),
	.SPO2(SPO2),
	.final_comp_done(final_comp_done)
	);


//instantiate fftbuffer led2
fft_buffer_led1_rhiddi_ftt fftbuff1(
	.clk (clk),
	.reset_n (in_reset_n),
	.led1 (led_two),
	.in_new_samples (new_samples),
	.led1_AC (led2_AC_computed),
	.led1_DC (led2_DC_computed),
	.out_new_data(led2_new_data), //led2_new_data //trying other algo dv
	.HR(), //HR //trying other algo
	.tx (tx)
	);

//instantiate fftbuffer led1
fft_buffer_led1_rhiddi_ftt fftbuff0(
	.clk (clk),
	.reset_n (in_reset_n),
	.led1 (led_one),
	.in_new_samples (new_samples),
	.led1_AC (led1_AC_computed),
	.led1_DC (led1_DC_computed),
	.out_new_data(led1_new_data),
	.HR (),
	.tx ()
	);

	TD_circ_buffer td0(
		.clk (clk),
		.reset_n (reset_n),
		.led1(led_one),
		.in_new_samples (new_samples),
		.led1_AC (),
		.led1_DC (),
		.HR (HR),
		.out_new_data(td_new_data)
		);
*/

//pio_0 is input into nios
//pio_1 is output to hardware

always@(posedge clk) 
begin 
	if (
end

	soc_system u0 (
		.clk_clk                          (clk),                          //                        clk.clk
		.pio_0_external_connection_export (<connected-to-pio_0_external_connection_export>), //  pio_0_external_connection.export
		.pio_1_external_connection_export (<connected-to-pio_1_external_connection_export>), //  pio_1_external_connection.export
		.reset_reset_n                    (reset_n),                    //                      reset.reset_n
		.uart_0_external_connection_rxd   (<connected-to-uart_0_external_connection_rxd>),   // uart_0_external_connection.rxd
		.uart_0_external_connection_txd   (<connected-to-uart_0_external_connection_txd>),   //                           .txd
		.uart_1_external_connection_rxd   (<connected-to-uart_1_external_connection_rxd>),   // uart_1_external_connection.rxd
		.uart_1_external_connection_txd   (<connected-to-uart_1_external_connection_txd>),   //                           .txd
		.uart_2_external_connection_rxd   (<connected-to-uart_2_external_connection_rxd>),   // uart_2_external_connection.rxd
		.uart_2_external_connection_txd   (<connected-to-uart_2_external_connection_txd>)    //                           .txd
	);



endmodule


