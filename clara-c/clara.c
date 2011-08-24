#include <atmcdLXd.h>
#include <stdio.h>
#include <math.h>
#include <unistd.h>
#include <malloc.h>

// calls to clara SDK have to return DRV_SUCCESS
#define C(cmd) do{\
  unsigned int ret=cmd;\
  if(DRV_SUCCESS!=ret)\
    printf("%s:%d in function %s at call to %s return=%d\n",\
	   __FILE__,__LINE__,__func__,#cmd,ret);\
}while(0)

at_32 clara_circ_buf_size;
unsigned short *clara_buf;
int clara_h,clara_w;
int temp_min=20,temp_shutoff=20;

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
  int h=432, w=412;
  clara_h=h;
  clara_w=w;
  C(SetIsolatedCropMode(1,h,w,1,1));
  C(GetSizeOfCircularBuffer(&clara_circ_buf_size));
  clara_buf=malloc(sizeof(*clara_buf)*
		   h*w*clara_circ_buf_size);
  if(!clara_buf)
    printf("can't allocate memory for pictures\n");
  C(SetAcquisitionMode(5 /*run till abort*/));
  C(SetTemperature(-55));
}

void
uninit_clara()
{
  C(SetTemperature(temp_shutoff));
  float t;
  GetTemperatureF(&t);
  while(fabsf(temp_shutoff-t)>5){
    printf("temperature is %f should be %d\n",
	   t,temp_shutoff);
    GetTemperatureF(&t);
    sleep(5);
  }
  C(ShutDown()); 
}

void
capture_clara()
{
  C(WaitForAcquisition());
  at_32 first,last;
  C(GetNumberNewImages(&first,&last));
  int n=last-first;
  printf("received %d images\n",1+n);
  at_32 pixels=(1+n)*clara_h*clara_w;
  at_32 validfirst,validlast;
  C(GetImages16(first,last,clara_buf,pixels,
		&validfirst,&validlast));
  if((validlast!=last) || (validfirst!=first))
    printf("couldn't get as many images as expected\n");
  int i,len=clara_h*clara_w;
  for(i=0;i<n+1;i++){
    unsigned long long sum=0;
    int j;
    for(j=0;j<len;j++)
      sum+=clara_buf[i*len+j];
    printf("sum %012lld\n",sum);
  }
}

int
main()
{
  init_clara();
  C(PrepareAcquisition());
  C(StartAcquisition());
  int i;
  for(i=0;i<100;i++)
    capture_clara();
  C(AbortAcquisition());
  C(FreeInternalMemory());
  uninit_clara();
  return 0;
}
