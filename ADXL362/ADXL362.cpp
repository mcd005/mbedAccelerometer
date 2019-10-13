#include "mbed.h"
#include "ADXL362.h"
 
// Class
 
ADXL362::ADXL362(PinName mosi, PinName miso, PinName sclk, PinName cbs)
	: SPI_m(mosi, miso, sclk) 
	, CBS_m(cbs) {
	CBS_m=1;
	}
	
// SPI 

void ADXL362::init_spi(){
	// spi 8 bits, mode 0, 1 MHz for adxl362
    SPI_m.format(8,0);
    // 5 MHz, max for acc - works fine
    SPI_m.frequency(5000000);
}



void ADXL362::init_adxl362(){
	//uint8_t reg;
	// reset the adxl362
    wait_ms(200);
    ACC_WriteReg(RESET, 0x52);
    wait_ms(200);

    // set FIFO
    ACC_WriteReg(FIFO_CTL,0x0A);  // stream mode, AH bit
    //ACC_WriteReg(FIFO_CTL,0x02);  // stream mode, no AH bit
    //reg = ACC_ReadReg(FIFO_CTL);
    //pc.printf("FIFO_CTL = 0x%X\r\n", reg);

	// Not used but keep in case it is important to set FIFO parameters.
    //ACC_WriteReg(FIFO_SAM,SAMPLE_SET * 3);   // fifo depth
    //reg = ACC_ReadReg(FIFO_SAM);
    //pc.printf("FIFO_SAM = 0x%X\r\n", reg);

    // set adxl362 to 4g range, 25Hz
    //ACC_WriteReg(FILTER_CTL,0x51);
    // 2g, 25Hz
    ACC_WriteReg(FILTER_CTL,0x11);
    //reg = ACC_ReadReg(FILTER_CTL);
    //printf("FILTER_CTL = 0x%X\r\n", reg);

    // map adxl362 interrupts
    //ACC_WriteReg(INTMAP1,0x01); //data ready
    ACC_WriteReg(INTMAP1,0x04); //watermark
    //reg = ACC_ReadReg(INTMAP1);
    //pc.printf("INTMAP1 = 0x%X\r\n", reg);

    // set adxl362 to measurement mode, ultralow noise
    ACC_WriteReg(POWER_CTL,0x22);
    //reg = ACC_ReadReg(POWER_CTL);
    //pc.printf("POWER_CTL = 0x%X\r\n", reg);
}

void ADXL362::ACC_GetXYZ8(int8_t* x, int8_t* y, int8_t* z)
{
    CBS_m = DOWN;
    SPI_m.write(RD_SPI);
    SPI_m.write(0x08);

    *x = SPI_m.write(0x00);
    *y = SPI_m.write(0x00);
    *z = SPI_m.write(0x00);

    CBS_m = UP;
}


uint8_t ADXL362::ACC_ReadReg( uint8_t reg )
{
    CBS_m = DOWN;
    SPI_m.write(RD_SPI);
    SPI_m.write(reg);
    uint8_t val = SPI_m.write(0x00);
    CBS_m = UP;
    return (val);
}

void ADXL362::ACC_WriteReg( uint8_t reg, uint8_t cmd )
{
    CBS_m = DOWN;
    SPI_m.write(WR_SPI);
    SPI_m.write(reg);
    SPI_m.write(cmd);
    CBS_m = UP;
}
