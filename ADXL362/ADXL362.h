#ifndef _ADXL362_H_
#define _ADXL362_H_

#include "mbed.h"

// ACC Registers
#define ID0 0x00
#define STATUS 0x0b
#define FIFO_EL 0x0c
#define FIFO_EH 0x0d
#define RESET 0x1f
#define FIFO_CTL 0x28
#define FIFO_SAM 0x29
#define INTMAP1 0x2a
#define INTMAP2 0x2b
#define FILTER_CTL 0x2c
#define POWER_CTL 0x2d
#define WR_SPI 0x0a
#define RD_SPI 0x0b
#define RD_FIFO 0x0d
#define DOWN 0
#define UP 1
#define SAMPLE_SET 128

/*		Class ADXL362: configure and connect to ADXL362 3-axis accelerometer.
 *		Richard McWilliam
 *
 *		Example:
 *
 *		#include "mbed.h"
 *		#include "ADXL362.h"
 *
 *		ADXL362 adxl362(p11, p12, p13, p10);  // Accelerometer (mosi, miso, sclk, cs)
 *
 *		int main()
 *		{
 *		// local variables
 *		int8_t x8 = 0;
 *		int8_t y8 = 0;
 *		int8_t z8 = 0;	
 *		uint8_t reg;
 *
 *		// set up SPI interface
 *		adxl362.init_spi();
 *		// Set up accelerometer
 *		adxl362.init_adxl362();
 *
 *		// Check settings
 *		reg = adxl362.ACC_ReadReg(FILTER_CTL);
 * 		printf("FILTER_CTL = 0x%X\r\n", reg);
 *
 *		adxl362.ACC_GetXYZ8(&x8, &y8, &z8); // Fetch sample from ADXL362
 *		wait(0.1); // Wait is required in this mode
 *			
 *		}
*/
class ADXL362 {
	
	public:
		// Set up object for communcation with ADXL362. Pins are mosi, miso, sclk, cs
		ADXL362(PinName mosi, PinName miso, PinName sclk, PinName cbs);
		//~ADXL362() {};
		
		// Initialise the SPI interface for ADXL362
		void init_spi();
		
		// Initialise ADXL362 in basic capture mode, 8 bit pcakets.
		void init_adxl362();
		
		// Fetch a single set of x,y,z packets indicating acceleration
		void ACC_GetXYZ8(int8_t* x, int8_t* y, int8_t* z);
		
		// Read specified register of ADXL362
		uint8_t ACC_ReadReg( uint8_t reg );
		
		// Write to register of ADXL362
		void ACC_WriteReg( uint8_t reg, uint8_t cmd );
	
	private:
		SPI SPI_m;
        DigitalOut CBS_m;		

};

#endif