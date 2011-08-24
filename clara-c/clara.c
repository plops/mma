#include <atmcdLXd.h>
#include <stdio.h>
#include <math.h>
#include <unistd.h>

// calls to clara SDK have to return DRV_SUCCESS
#define C(cmd) do{if(DRV_SUCCESS!=cmd)printf("%s:%d in function %s at call to %s\n",__FILE__,__LINE__,__func__,#cmd);}while(0)

at_32 clara_circ_buf_size;

int temp_min=-55,temp_shutoff=-55;

void
init_clara()
{
  at_32 n,handle;
  C(GetAvailableCameras(&n));
  C(GetCameraHandle(n-1,&handle));
  C(SetCurrentCamera(handle));
  C(Initialize("/usr/local/etc/andor"));
  C(SetTriggerMode(1 /*external*/));
  C(SetExposureTime(.01521));
  C(SetReadMode(4 /*image*/));
  C(SetAcquisitionMode(1 /*single scan*/));
  C(CoolerON());
  C(SetADChannel(1 /*fast*/));
  C(SetFastExtTrigger(1));
  C(SetFrameTransferMode(1));
  C(SetIsolatedCropMode(1,432,412,1,1));
  C(GetSizeOfCircularBuffer(&clara_circ_buf_size));
  C(SetAcquisitionMode(5 /*run till abort*/));
  C(SetTemperature(-55));
}

void
uninit_clara()
{
  C(SetTemperature(temp_shutoff));
  float t;
  C(GetTemperatureF(&t));
  while(fabsf(temp_shutoff-t)>5){
    printf("temperature is %f should be %d\n",
	   t,temp_shutoff);
    C(GetTemperatureF(&t));
    sleep(5);
  }
  C(ShutDown()); 
}

int
main()
{
  init_clara();
  return 0;
}
