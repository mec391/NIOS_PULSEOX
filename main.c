#define FIXED_POINT 16
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

unsigned int receive(char prebuffer1[], char prebuffer2[]);
void perform_comp(signed int buff16_1[], signed int buff16_2[], unsigned int *hr, unsigned int *spo2);
void transmit(unsigned int hr, unsigned int spo2);

int main()
{

	/*
	 * 1. is last value of buffer full? no, keep reading uart until it is
	 * 2. Yes? perform comp, write final values, read for next data value, replace prev one with new one
	 *
	 */

	char prebuffer1[3];
	char prebuffer2[3];
	unsigned long int buffer1[1024];
	unsigned long int buffer2[1024];
	signed int buff16_1[1024];
	signed int buff16_2[1024];
	unsigned int start_cnt = 0;
	unsigned int numbytes;
	while (start_cnt < 1024)
	{

		numbytes =	receive(prebuffer1, prebuffer2);
		if (numbytes == 6)
		{
			buffer1[start_cnt] = (unsigned long int){prebuffer1[0], prebuffer1[1], prebuffer1[2]};
			buffer2[start_cnt] = (unsigned long int){prebuffer2[0], prebuffer2[1], prebuffer2[2]};
			buff16_1[start_cnt] =(signed int) buffer1[start_cnt]>>6;
			buff16_2[start_cnt] =(signed int) buffer2[start_cnt]>>6;
			start_cnt = start_cnt + 1;
		}

	}
	while(1)
		numbytes = 0;
		unsigned int hr;
		unsigned int spo2;
		unsigned int buffer_cnt = 0;
		perform_comp(buff16_1, buff16_2, &hr, &spo2);
		transmit(hr, spo2);
		while (numbytes < 6) receive(prebuffer1, prebuffer2);
		if (buffer_cnt == 1023)	buffer_cnt = 0;
		else buffer_cnt = buffer_cnt + 1;
		buffer1[buffer_cnt] = (unsigned long int){prebuffer1[0], prebuffer1[1], prebuffer1[2]};
		buffer2[buffer_cnt] = (unsigned long int){prebuffer2[0], prebuffer2[1], prebuffer2[2]};
		buff16_1[start_cnt] =(signed int) buffer1[start_cnt]>>6;
		buff16_2[start_cnt] =(signed int) buffer2[start_cnt]>>6;
}

unsigned int receive(char prebuffer1[], char prebuffer2[])
{
	unsigned int numbytes;
	FILE* fp1;
	FILE* fp2;

	fp1 = fopen("/dev/uart_1", "r+");
	numbytes = fread(prebuffer1, sizeof(prebuffer1)/sizeof(prebuffer1[0]), 3, fp1);
	fclose(fp1);

	fp2 = fopen("/dev/uart_2", "r+");
	numbytes = numbytes + fread(prebuffer2, sizeof(prebuffer2)/sizeof(prebuffer2[0]), 3, fp2);
	fclose(fp2);

	return numbytes;
}

void transmit(unsigned int hr, unsigned int spo2)
{

//for now write to jtag uart instead of back to the device
printf("HR = %d		     SPO2 = %d", hr, spo2);



}


void perform_comp(signed int buff16_1[], signed int buff16_2[], unsigned int *hr, unsigned int *spo2)
{
	unsigned int nfft = 1024;
	kiss_fftr_cfg cfg = kiss_fftr_alloc(nfft, 0, 0, 0);
	kiss_fft_scalar cx_in[nfft];
	for (int i = 0; i < nfft; i++) cx_in[i] = buff16_1[i];
	kiss_fft_cpx cx_out[nfft/2+1];



	kiss_fftr(cfg, cx_in, cx_out);
	unsigned int DC_1 = sqrt(cx_out[0].r * cx_out[0].r + cx_out[0].i * cx_out[0].i);
    unsigned int sort[512];
    unsigned int AC_1 = 0;
    unsigned int HR_1 = 0;
    for (int i = 13; i < 512; i++) sort[i] = sqrt(cx_out[i].r * cx_out[i].r + cx_out[i].i * cx_out[i].i);
    for (int i = 13; i < 512; i++)
		{
			if (sort[i] > AC_1);
			{
				AC_1 = sort[i];
				HR_1 = i;
			}
		}
	free(cfg);
//repeat for the second led
		 nfft = 1024;
		kiss_fftr_cfg cfg2 = kiss_fftr_alloc(nfft, 0, 0, 0);
		kiss_fft_scalar cx_in2[nfft];
		for (int i = 0; i < nfft; i++) cx_in[i] = buff16_2[i];
		kiss_fft_cpx cx_out2[nfft/2+1];



		kiss_fftr(cfg2, cx_in2, cx_out2);
		unsigned int DC_2 = sqrt(cx_out2[0].r * cx_out2[0].r + cx_out2[0].i * cx_out2[0].i);

	    unsigned int AC_2 = 0;
	    unsigned int HR_2 = 0;
	    for (int i = 13; i < 512; i++) sort[i] = sqrt(cx_out2[i].r * cx_out2[i].r + cx_out2[i].i * cx_out2[i].i);
	    for (int i = 13; i < 512; i++)
			{
				if (sort[i] > AC_2);
				{
					AC_2 = sort[i];
					HR_2 = i;
				}
			}
		free(cfg2);
//compute spo2
unsigned int spo2_calc = (AC_1 / DC_1) / (AC_2 / DC_2) * 100;
*hr = HR_1;
*spo2 = spo2_calc;
}

