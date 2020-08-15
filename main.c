//#define FIXED_POINT 16 //we use floating point now
#include "altera_avalon_uart.h"
#include "altera_avalon_uart_regs.h"
# include <stdio.h>
# include <stddef.h>
#include <time.h>
#include "kiss_fftr.h"
#include <math.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <stdint.h>
unsigned int receive(unsigned char prebuffer1[], unsigned char prebuffer2[]);
void perform_comp(float buff16_1[], float buff16_2[], float *hr, float *spo2);
void transmit(float hr, float spo2);

int main()
{

	/*
	 * 1. is last value of buffer full? no, keep reading uart until it is
	 * 2. Yes? perform comp, write final values, read for next data value, replace prev one with new one
	 *
	 */
	printf("system started!!\n");
	unsigned char prebuffer1[3];
	unsigned char prebuffer2[3];
	uint32_t buffer1[1024]; //unsigned int version of data
	uint32_t buffer2[1024];
	float buff_f_1[1024]; //float version of data
	float buff_f_2[1024];
	unsigned int start_cnt = 0;
	unsigned int numbytes;
	uint8_t byte0;
	uint8_t byte1;
	uint8_t byte2;
	while (start_cnt < 1024)
	{

		numbytes =	receive(prebuffer1, prebuffer2);
		printf("numbytes = %d\n", numbytes);
		printf("prebuffer1 = %d \n", prebuffer1[0]);
		printf("prebuffer1 = %d \n", prebuffer1[1]);
		printf("prebuffer1 = %d \n", prebuffer1[2]);
		printf("prebuffer2 = %d \n", prebuffer2[0]);
		printf("prebuffer2 = %d \n", prebuffer2[1]);
		printf("prebuffer2 = %d \n", prebuffer2[2]);
		if (numbytes == 6)
		{	byte0 = (uint8_t) prebuffer1[0]; byte1 = (uint8_t) prebuffer1[1]; byte2 = (uint8_t) prebuffer1[2];
			buffer1[start_cnt] = (byte0 << 16) | (byte1 << 8) | byte2;
			byte0 = (uint8_t) prebuffer2[0]; byte1 = (uint8_t) prebuffer2[1]; byte2 = (uint8_t) prebuffer2[2];
			buffer2[start_cnt] = (byte0 << 16) | (byte1 << 8) | byte2;
			//buffer1[start_cnt] = (uint32_t){prebuffer1[0], prebuffer1[1], prebuffer1[2]};
			//buffer2[start_cnt] = (uint32_t){prebuffer2[0], prebuffer2[1], prebuffer2[2]};
			buff_f_1[start_cnt] =(float) buffer1[start_cnt] * 1.2 / 2097152;
			buff_f_2[start_cnt] =(float) buffer2[start_cnt] * 1.2 / 2097152;
			//printf("prebuffer1 = %d prebuffer2 = %d \n", buffer1[start_cnt], buffer2[start_cnt]);
			//printf("prebuffer1 = %f prebuffer2 = %f \n", buff_f_1[start_cnt], buff_f_2[start_cnt]);
			start_cnt = start_cnt + 1;
		}

	}
	printf("Buffers filled!!!!\n");
	//for (int i = 0; i < 1024; i++) printf("led1 = %f led2 = %f\n", buff_f_1[i], buff_f_2[i]);
	  for (int i = 0; i < 1024; i++) printf("%f, ", buff_f_1[i]);
	while(1)
	{
		numbytes = 0;
		float hr;
		float spo2;
		unsigned int buffer_cnt = 0;
		perform_comp(buff_f_1, buff_f_2, &hr, &spo2);
		transmit(hr, spo2);
		while (numbytes < 6) receive(prebuffer1, prebuffer2);
		if (buffer_cnt == 1023)	buffer_cnt = 0;
		else buffer_cnt = buffer_cnt + 1;
		byte0 = (uint8_t) prebuffer1[0]; byte1 = (uint8_t) prebuffer1[1]; byte2 = (uint8_t) prebuffer1[2];
		buffer1[buffer_cnt] = (byte0 << 16) | (byte1 << 8) | byte2;
		byte0 = (uint8_t) prebuffer2[0]; byte1 = (uint8_t) prebuffer2[1]; byte2 = (uint8_t) prebuffer2[2];
		buffer2[buffer_cnt] = (byte0 << 16) | (byte1 << 8) | byte2;
		//buffer1[buffer_cnt] = (uint32_t){prebuffer1[0], prebuffer1[1], prebuffer1[2]};
		//buffer2[buffer_cnt] = (uint32_t){prebuffer2[0], prebuffer2[1], prebuffer2[2]};
		buff_f_1[buffer_cnt] =(float) buffer1[buffer_cnt] * 1.2 / 2097152;
		buff_f_2[buffer_cnt] =(float) buffer2[buffer_cnt] * 1.2 / 2097152;
	}
}

unsigned int receive(unsigned char prebuffer1[], unsigned char prebuffer2[])
{
	unsigned int numbytes;
	int fp1;
	int fp2;
	fp1 = open("/dev/uart_1", O_RDWR | O_NOCTTY | O_NONBLOCK);//fopen("/dev/uart_1", "r+");
	numbytes = read(fp1, prebuffer1, 3);
	close(fp1);

	fp2 = open("/dev/uart_2", O_RDWR | O_NOCTTY | O_NONBLOCK);//fopen("/dev/uart_2", "r+");
	numbytes = numbytes + read(fp2, prebuffer2, 3);
	close(fp2);

	return numbytes;
}

void transmit(float hr, float spo2)
{

//for now write to jtag uart instead of back to the device
printf("HR = %f		     SPO2 = %f", hr, spo2);



}


void perform_comp(float buff_f_1[], float buff_f_2[], float *hr, float *spo2)
{
	printf("comp performing!!!\n");
	unsigned int nfft = 1024;
	kiss_fftr_cfg cfg = kiss_fftr_alloc(nfft, 0, 0, 0);
	kiss_fft_scalar cx_in[nfft];
	for (int i = 0; i < nfft; i++) cx_in[i] = buff_f_1[i];
	kiss_fft_cpx cx_out[nfft/2+1];



	kiss_fftr(cfg, cx_in, cx_out);
	float DC_1 = sqrt(cx_out[0].r * cx_out[0].r + cx_out[0].i * cx_out[0].i);
    float sort[512];
    float AC_1 = 0;
    float HR_1 = 0;
    for (int i = 13; i < 512; i++) sort[i] = sqrt(cx_out[i].r * cx_out[i].r + cx_out[i].i * cx_out[i].i);
    for (int i = 13; i < 512; i++)
		{
			if (sort[i] > AC_1)
			{
				AC_1 = sort[i];
				HR_1 = i * .04 * 60;
			}
		}
	free(cfg);
//repeat for the second led
		nfft = 1024;
		kiss_fftr_cfg cfg2 = kiss_fftr_alloc(nfft, 0, 0, 0);
		kiss_fft_scalar cx_in2[nfft];
		for (int i = 0; i < nfft; i++) cx_in[i] = buff_f_2[i];
		kiss_fft_cpx cx_out2[nfft/2+1];



		kiss_fftr(cfg2, cx_in2, cx_out2);
		float DC_2 = sqrt(cx_out2[0].r * cx_out2[0].r + cx_out2[0].i * cx_out2[0].i);

	    float AC_2 = 0;
	    float HR_2 = 0;
	    for (int i = 13; i < 512; i++) sort[i] = sqrt(cx_out2[i].r * cx_out2[i].r + cx_out2[i].i * cx_out2[i].i);
	    for (int i = 13; i < 512; i++)
			{
				if (sort[i] > AC_2)
				{
					AC_2 = sort[i];
					HR_2 = i * .04 * 60;
				}
			}
		free(cfg2);
//compute spo2
float spo2_calc = (AC_1 / DC_1) / (AC_2 / DC_2) * 100;
*hr = HR_1;
*spo2 = spo2_calc;
}

