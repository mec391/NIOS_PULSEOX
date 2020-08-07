#include "altera_avalon_uart.h"
#include "altera_avalon_uart_regs.h"
# include <stdio.h>
# include <stddef.h>
#include <time.h>

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
	unsigned int start_cnt = 0;
	while (start_cnt < 1024)
	{

		numbytes =	receive(prebuffer1, prebuffer2);
		if (numbytes == 6)
		{
			buffer1[start_cnt] = (unsigned long int){prebuffer1[0], prebuffer1[1], prebuffer1[2]};
			buffer2[start_cnt] = (unsigned long int){prebuffer2[0], prebuffer2[1], prebuffer2[2]};
			start_cnt = start_cnt + 1;
		}

	}
	while(1)
		numbytes = 0;
		unsigned int hr;
		unsigned int spo2;
		unsigned int buffer_cnt = 0;
		perform_comp(buffer1, buffer2, &hr, &spo2);
		transmit(hr, spo2);
		while (numbytes < 6) receive(prebuffer1, prebuffer2);
		if (buffer_cnt == 1023)	buffer_cnt = 0;
		else buffer_cnt = buffer_cnt + 1;
		buffer1[buffer_cnt] = (unsigned long int){prebuffer1[0], prebuffer1[1], prebuffer1[2]};
		buffer2[buffer_cnt] = (unsigned long int){prebuffer2[0], prebuffer2[1], prebuffer2[2]};
}

unsigned int receive(char prebuffer1[], char prebuffer2[])
{
	unsigned int numbytes;
	FILE* fp1;
	FILE* fp2;

	fp1 = fopen("/dev/uart_1", "r+");
	numbytes = fread(led_1, size_t(led_1), 3, fp);
	fclose(fp1);

	fp2 = fopen("/dev/uart_2", "r+");
	numbytes = numbytes + fread(led_2, size_t(led_2), 3, fp);
	fclose(fp2);

	return numbytes;
}

void transmit(unsigned int hr, unsigned int spo2)
{






}


void perform_comp(unsigned long int buffer1[], unsigned long int buffer2[])
{



}

