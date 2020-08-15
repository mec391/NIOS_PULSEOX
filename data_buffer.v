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
					4'b1011: //run to 1100 -- hold new_samples for 2 clock cycles because SM going into UART is running at half clk speed
							begin
								out_addr <= 3'b101;
								led_one_aled_one <= in_strm_data[21:0];
								reg_counter <= 4'b1100; //reg_counter <= 4'b0000;
								new_samples <= 1;
							end
					4'b1100: 
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
//assign final_comp_complete =  ///put the dv for comp done here

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
reg [3:0] cnt = 0;
reg [7:0] downsampler = 0;
always@(posedge half_clk)
begin

	case (cnt)
	4'd0:begin if (new_samples) cnt <= 1;
		  else cnt <= cnt;end
    4'd1:begin if(downsampler == 12)
    	  begin
    	  	downsampler <= 0;
    	  	cnt <= 4'd2;
    	  end
    	  else
    	  begin
    	  	downsampler <= downsampler + 1;
    	  	cnt <= 0;
    	  end end
    4'd2:begin uart_tx_data1 <= 8'd255;//{2'b0, led_one[21:16]};
    		   tx_dv1 <= 1;
    		   cnt <= 3;end
   	4'd3:begin	tx_dv1 <= 0;
   				if(tx_done1 == 1) cnt <= 4;
   				else cnt <= cnt;end
   	4'd4:begin
   				uart_tx_data1 <= 8'd254;//led_one[15:8];
   				tx_dv1 <= 1;
   				cnt <= 5;end
   	4'd5:begin 
   				tx_dv1 <= 0;
   				if(tx_done1 == 1) cnt <= 6;
   				else cnt <= cnt;end
   	4'd6:begin
   				uart_tx_data1 <= 8'd253;//led_one[7:0];
   				tx_dv1 <= 1;
   				cnt <= 7;end
   	4'd7:begin
   				tx_dv1 <= 0;
   				uart_tx_data2 <= 8'd252;//{2'b0, led_two[21:16]};
   				tx_dv2 <= 1;
   				cnt = 8;end
   	4'd8:begin
   				tx_dv2 <= 0;
   				if(tx_done2 == 1) cnt <= 9;
   				else cnt <= cnt;end
    4'd9:begin
    			uart_tx_data2 <= 8'd251;//led_two[15:8];
    			tx_dv2 <= 1;
    			cnt = 10;end
    4'd10:begin
    			tx_dv2 <= 0;
    			if(tx_done2 == 1)cnt <= 11;
    			else cnt <= cnt;end
    4'd11:begin
    			uart_tx_data2 <= 8'd250;//led_two[7:0];
    			tx_dv2 <= 1;
    			cnt = 12;end
   	4'd12:begin
   				tx_dv2 <= 0;
   				cnt = 0;end
	endcase
end

reg tx_dv1;
reg [7:0] uart_tx_data1;
wire tx_busy1;
wire tx1;
wire tx_done1;
reg tx_dv2;
reg [7:0] uart_tx_data2;
wire tx_busy2;
wire tx2;
wire tx_done2;
wire half_clk;

divide_by_2 div5000(
 .clk (clk),
 .reset_n (in_reset_n),
 .half_clk (half_clk)


	);

uart_tx1 utx1(
.i_Clock (half_clk),
.i_Tx_DV (tx_dv1),
.i_Tx_Byte (uart_tx_data1),
.o_Tx_Active (tx_busy1),
.o_Tx_Serial (tx1),
.o_Tx_Done (tx_done1),
.reset_n (in_reset_n)
  );

uart_tx1 utx2(
.i_Clock (half_clk),
.i_Tx_DV (tx_dv2),
.i_Tx_Byte (uart_tx_data2),
.o_Tx_Active (tx_busy2),
.o_Tx_Serial (tx2),
.o_Tx_Done (tx_done2),
.reset_n (in_reset_n)
  );

	soc_system u0 (
		.clk_clk                          (clk),                          //                        clk.clk
		//.pio_0_external_connection_export (), //  pio_0_external_connection.export
		//.pio_1_external_connection_export (), //  pio_1_external_connection.export
		.reset_reset_n                    (in_reset_n),                    //                      reset.reset_n
		//.uart_0_external_connection_rxd   (),   // uart_0_external_connection.rxd
		//.uart_0_external_connection_txd   (),   //                           .txd
		.uart_1_external_connection_rxd   (tx1),   // uart_1_external_connection.rxd
		.uart_1_external_connection_txd   (),   //                           .txd
		.uart_2_external_connection_rxd   (tx2),   // uart_2_external_connection.rxd
		.uart_2_external_connection_txd   ()    //                           .txd
	);



endmodule


//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
//////////////////////////////////////////////////////////////////////
// This file contains the UART Transmitter.  This transmitter is able
// to transmit 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When transmit is complete o_Tx_done will be
// driven high for one clock cycle.
//
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
//////////////////////////////////////////////////////////////////////
// File Downloaded from http://www.nandland.com
//////////////////////////////////////////////////////////////////////
// This file contains the UART Transmitter.  This transmitter is able
// to transmit 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When transmit is complete o_Tx_done will be
// driven high for one clock cycle.
//
// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = (Frequency of i_Clock)/(Frequency of UART)
// Example: 10 MHz Clock, 115200 baud UART
// (10000000)/(115200) = 87
  
module uart_tx1 
  #(parameter CLKS_PER_BIT = 217)
  (
   input       i_Clock,
   input reset_n,
   input       i_Tx_DV,
   input [7:0] i_Tx_Byte, 
   output      o_Tx_Active,
   output reg  o_Tx_Serial,
   output      o_Tx_Done
   );
  
  parameter s_IDLE         = 3'b000;
  parameter s_TX_START_BIT = 3'b001;
  parameter s_TX_DATA_BITS = 3'b010;
  parameter s_TX_STOP_BIT  = 3'b011;
  parameter s_CLEANUP      = 3'b100;
   
  reg [2:0]    r_SM_Main     = 0;
  reg [7:0]    r_Clock_Count = 0;
  reg [2:0]    r_Bit_Index   = 0;
  reg [7:0]    r_Tx_Data     = 0;
  reg          r_Tx_Done     = 0;
  reg          r_Tx_Active   = 0;
     
  always @(posedge i_Clock)
    begin
       if(~reset_n)
       begin 
       r_SM_Main <= s_IDLE;
       end
      case (r_SM_Main)
        s_IDLE :
          begin
            o_Tx_Serial   <= 1'b1;         // Drive Line High for Idle
            r_Tx_Done     <= 1'b0;
            r_Clock_Count <= 0;
            r_Bit_Index   <= 0;
             
            if (i_Tx_DV == 1'b1)
              begin
                r_Tx_Active <= 1'b1;
                r_Tx_Data   <= i_Tx_Byte;
                r_SM_Main   <= s_TX_START_BIT;
              end
            else
              r_SM_Main <= s_IDLE;
          end // case: s_IDLE
         
         
        // Send out Start Bit. Start bit = 0
        s_TX_START_BIT :
          begin
            o_Tx_Serial <= 1'b0;
             
            // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_TX_START_BIT;
              end
            else
              begin
                r_Clock_Count <= 0;
                r_SM_Main     <= s_TX_DATA_BITS;
              end
          end // case: s_TX_START_BIT
         
         
        // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
        s_TX_DATA_BITS :
          begin
            o_Tx_Serial <= r_Tx_Data[r_Bit_Index];
             
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_TX_DATA_BITS;
              end
            else
              begin
                r_Clock_Count <= 0;
                 
                // Check if we have sent out all bits
                if (r_Bit_Index < 7)
                  begin
                    r_Bit_Index <= r_Bit_Index + 1;
                    r_SM_Main   <= s_TX_DATA_BITS;
                  end
                else
                  begin
                    r_Bit_Index <= 0;
                    r_SM_Main   <= s_TX_STOP_BIT;
                  end
              end
          end // case: s_TX_DATA_BITS
         
         
        // Send out Stop bit.  Stop bit = 1
        s_TX_STOP_BIT :
          begin
            o_Tx_Serial <= 1'b1;
             
            // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
            if (r_Clock_Count < CLKS_PER_BIT-1)
              begin
                r_Clock_Count <= r_Clock_Count + 1;
                r_SM_Main     <= s_TX_STOP_BIT;
              end
            else
              begin
                r_Tx_Done     <= 1'b1;
                r_Clock_Count <= 0;
                r_SM_Main     <= s_CLEANUP;
                r_Tx_Active   <= 1'b0;
              end
          end // case: s_Tx_STOP_BIT
         
         
        // Stay here 1 clock
        s_CLEANUP :
          begin
            r_Tx_Done <= 1'b1;
            r_SM_Main <= s_IDLE;
          end
         
         
        default :
          r_SM_Main <= s_IDLE;
         
      endcase
    end
 
  assign o_Tx_Active = r_Tx_Active;
  assign o_Tx_Done   = r_Tx_Done;
   
endmodule



