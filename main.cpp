#include "mbed.h"
#include <stdio.h>
#include <math.h>
#include "ADXL362.h"

#define PI 3.14159265
#define TRUE 1
#define FALSE 0

/* function declaration */
void initialise_setup();
void retrieve_fromfile(float *T, double *d);

DigitalOut led1(LED1);
DigitalOut led2(LED4);
float tilt_pitch[3500];
float tilt_roll[3500];          // global arrays stored on heap

/* Serial device declaration */
Serial pc(USBTX, USBRX);        // serial tx, rx
/* Accelerometer object declaration (mosi, miso, sclk, cs) */
ADXL362 adxl362(p11, p12, p13, p10);

LocalFileSystem local("local"); // allows program to read and write to setup on the same disk drive that is used to program the mbed

/* PROGRAM DESCRIPTION*/
int main()
{
    pc.baud (115200);           
    initialise_setup();          // see function description
    /*Define parameters*/
    float T =1.0;               // sample rate (seconds)
    double d =1.0;              // sample time (hours)
    retrieve_fromfile(&T, &d);  // synchronisation between setup file and program variables at runtime
    int8_t xdata, ydata, zdata;
    int n = ((d*3600)/T)+1;     // number of samples

    adxl362.init_spi();         // Set up SPI interface
    adxl362.init_adxl362();     // set up accelerometer
    wait(0.1);                  // wait 100ms for accelerometer to initialise

    int i=0;
    while(i <= n) {
        adxl362.ACC_GetXYZ8(&xdata,&ydata,&zdata);//fetch readings

        double x = xdata;
        double y = ydata;
        double z = zdata;       /*x,y,z values are stored in clearly labelled variables so they can be clearly & easily used by the
                                    following formula for greater readability.*/

        tilt_pitch[i]= - atan2(-y,z) * (180.0 / PI);
        tilt_roll[i]=atan2(x, sqrt(y*y + z*z)) * (180.0 / PI);/*Formulas applied to x,y,z data to compute the tilt in pitch and roll
                                                              direction. The value is then stored in the appropriate array location.*/
        wait(T);                // wait until next reading should be taken
        i=i++;
        i%2 == 0 ? led1=1 : led1=0;// led on when index is even, off when odd. LED flashes with frequency proportional to sample rate
    }
    led1=0;
    while(1) {
        char c = pc.getc();
        if(c == 'c') {          // if MATLAB, triggered by character 'c' on serial bus, requests data capture:
            led2=1;             // LED Status light turns on for duration of transfer
            for(int a = 0; a < n+1; a++ ) {
                printf("%f %f\n", tilt_pitch[a], tilt_roll[a]);// print data across serial bus to MATLAB
            }
            led2=0;
        }
    }
}

/* Function retreives sample time and rate from setup file located in local file system*/
void retrieve_fromfile(float *T, double *d)
{
    char lineA[20], lineB[10], lineC[10];   // temporarily store first three lines of text
    int rate;
    float time;
    FILE *set = fopen("/local/setup.txt", "r");// Open "setup.txt" on the local file system for read
    if(set == NULL) {                       // should never be reached as initilise_setup will ensure the file exists
        fclose(set);
        led1=1;led2=1;                      // illuminate both LEDs to represent an error has occurred
    } else {
        fscanf(set,"%s",lineA);             // ignore first line
        fscanf(set,"%s %i",lineB,&rate);    // read sample rate
        fscanf(set,"%s %g",lineC,&time);    // read sample time
        fclose(set);
    }

    *T = rate/float(1000);
    *d = time;
}

/* Function creates and populates the setup.txt file IF it doesn’t already exist*/
void initilise_setup()
{
    FILE *set = fopen("/local/setup.txt", "r");         // open "setup.txt" on the local file system for read
    if(set == NULL) {                                   // if "setup.txt" can't be found create it
        FILE * fp;
        fp = fopen("/local/setup.txt" ,"w");
        fprintf(fp, "<configuration>\r\n");
        fprintf(fp, "sample= %i\r\n", 500);
        fprintf(fp, "duration= %g\r\n\r\n", 0.00277778);
        fprintf(fp, "****************************** REFERENCE ******************************\r\n\r\n");
        fprintf(fp, "sample period recorded in milliseconds (x10^-3 seconds)\r\n");
        fprintf(fp, "duration of capture recorded in hours\r\n\r\n");
        fprintf(fp, "  duration  | time (in hours)\r\n");
        fprintf(fp, "-----------------------------\r\n");
        fprintf(fp, "  10 seconds|  0.00277778\r\n");
        fprintf(fp, "   1 minute |  0.01666667\r\n");
        fprintf(fp, "  30 minutes|  0.50000000\r\n");
        fprintf(fp, "   1 hour   |  1.00000000\r\n");
        fprintf(fp, "   1 week   |  168.000000\r\n");
        fprintf(fp, "   4 weeks  |  672.000000\r\n");
        fprintf(fp, "   1 year   |  8760.00000");       // populate fp
        fclose(fp);                                     // close new setup file
    }
    fclose(set);                                        // close original setup file
}