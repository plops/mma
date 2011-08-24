#include <atmcdLXd.h>
#include <stdio.h>
#include <math.h>
#include <unistd.h>
#include <malloc.h>
#include <GL/glfw.h>
#include <stdlib.h>
#include <sys/time.h>
#include "slm.h"

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
  while(fabsf(temp_shutoff-t)>20){
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
  //printf("received %d images\n",1+n);
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
    if(sum>92055092)
      printf("X");
    else
      printf(".");

    //printf("sum %012lld\n",sum);
  }
}

int lcos_running=1;

void GLFWCALL
keyhandler(int key,int action)
{
  if(action!=GLFW_PRESS)
    return;
  if(key==GLFW_KEY_ESC)
    lcos_running=GL_FALSE;
  return;
}

// OpenGL Modelview Matrix
float m[4*4];

// Initialized Modelview matrix to do the affine transform from Camera
// coordinates into LCoS coordinates.
void
init_matrix()
{
  float s=.8283338739,
    sx=s,sy=-s,phi=-3.1017227,
    cp=cos(phi),sp=sin(phi),
    tx=608.43307,
    ty=168.91883;
  m[0]=sx*cp;
  m[1]=-1*sx*sp;
  m[2]=0;
  m[3]=0;
  
  m[4]=sy*sp;
  m[5]=sy*cp;
  m[6]=0.;
  m[7]=0.;

  m[8]=0;
  m[9]=0;
  m[10]=1;
  m[11]=0;
  
  m[12]=tx;
  m[13]=ty;
  m[14]=0;
  m[15]=1;
}


void
init_lcos()
{
  
  // make sure frame rate update cycle is phase locked to vertical
  // refresh of screen. On Nvidia hardware this can be done by setting
  // the following environment variable.
  setenv("__GL_SYNC_TO_VBLANK","1",1); 
  
  if(!glfwInit())
    printf("can't initialize opengl\n");
  int width=1280,height=1024;
   
  if(!glfwOpenWindow(width,height,8,8,8,
		     0,0,0,
		     GLFW_WINDOW)){
    printf("can't open opengl window\n");
  }

  printf("lcos started %dx%d\n",width,height);

  glfwSetWindowTitle("LCoS");
  //glfwSetWindowPos(-8,-31);

  // use glfw method to sync to vertical refresh
  glfwSwapInterval(1);

  glfwSetKeyCallback(keyhandler);
  init_matrix();
  
  glMatrixMode(GL_PROJECTION);
  glOrtho(0,1280,1024,0,-1,1);
  glMatrixMode(GL_MODELVIEW);
}

int frame_count=0;

void
draw_lcos()
{

  frame_count++;
  
  glClear(GL_COLOR_BUFFER_BIT);
  glLoadMatrixf(m);


  
  if((frame_count<10) ) //|| (frame_count%2)==0)
    glColor4f(1,1,1,1);
  else
    glColor4f(0,0,0,1);

  glRectf(0,0,400,400);
  
  glfwSwapBuffers();
}

void
uninit_lcos()
{
  glfwCloseWindow();
  glfwTerminate();
  printf("bye from lcos\n");
}

unsigned short *mma_buf;
enum{N=256,NN=N*N};
#define len(x) (sizeof(x)/sizeof(x[0]))
#define e(q) do{printf("error in file %s:%d in function %s, while calling %s\n",__FILE__,__LINE__,__FUNCTION__,q);}while(0)

void
print_status_mma()
{
  unsigned int stat,error;
  if(0!=SLM_ReadStatus(&stat,&error))
    e("read-status");
  printf("status 0x%x error 0x%x\n",stat,error);
}

void
draw_mma(unsigned short picture_nr,
	 unsigned short last_picture_p,
	 unsigned short ready_out_p)
{
  if(0!=SLM_WriteMatrixData(picture_nr,3,mma_buf,N*N))
    printf("error upload-image\n");
  if(0!=SLM_SetPictureSequence(picture_nr,last_picture_p,ready_out_p))
    e("set-picture-sequence");
}

void uninit_mma();
void
init_mma()
{
  mma_buf=malloc(N*N*sizeof(*mma_buf));
  if(!mma_buf)
    printf("error while allocating mma_buf\n");

  int i;
  for(i=0;i<NN;i++)
    mma_buf[i]=90;
  if(0!=SLM_RegisterBoard(0x0036344B00800803LL,
			  "192.168.0.2","255.255.255.0",
			  "0.0.0.0",4001)){
    e("register board");
  }
  if(0!=SLM_SetLocalIf("192.168.0.1",4001)){
    e("set local interface");
  }
  if(0!=SLM_Connect()){
    e("connect");
  }
  
  print_status_mma();
  
  if(0!=SLM_LoadConfiguration("/home/martin/cyberpower-mit/mma-essentials-0209/800803_dmdl6_20110215.ini")){
    e("config");
    uninit_mma();
    exit(-1);
  }
  
  if(0!=SLM_LoadCalibrationData("/home/martin/mma-essentials-0209/VC2481_15_67_2011-02-01_0-250nm_Rand7_Typ1.cal"))
    e("calib");

  if(0!=SLM_SetVoltage(SLM_SMART_IDX_VFRAME_F,15.0))
    e("set voltage vframe deflection phase");
  
  if(0!=SLM_SetVoltage(SLM_SMART_IDX_VFRAME_L,15.0))
    e("set voltage vframe load phase");

  
  // user ready should start 20us after deflection phase and go low at
  // the same time 
  float d0=101.,d=20.,width=15.24;
  if(0!=SLM_SetDeflectionPhase(d0,width*1000.))
    e("deflection");

  if(0!=SLM_SetExternReady(d0+d,width*1000.-d))
    e("extern ready");

  if(0!=SLM_EnableExternStart())
    e("enable extern start");

  float deflection=473.0/4;
  if(0!=SLM_SetParameter(1001,&deflection,4))
    e("set parameter 1001");

  if(0!=SLM_SetCycleTime(33.27 //180.
			 //2.*width+.01
			 ))
    e("cycle time");

  print_status_mma();


  if(0!=SLM_SetPowerOn())
    e("power");
  
  if(0!=SLM_WriteMatrixData(1,3,mma_buf,NN)) // you have to make sure to upload at least one image
    e("fill");

  if(0!=SLM_SetPictureSequence(1,1,1))
    e("set-picture-sequence");


  printf("infront of start\n");
  if(0!=SLM_SetStartMMA())
    e("start");

  // the first time when start-mma is executed, one should wait
  // 100ms..1s (try increasing the delay without matrix until read-status
  // returns the appropriate error)
  usleep(100000);
  // make sure you often call read-status to detect and clear
  // errors. if errors aren't cleared certain functions (like
  // start-mma) will never succeed.

  print_status_mma();
}

void
sync_mma()
{
  if(0!=SLM_SetStopMMA())
    e("stop mma");
  if(0!=SLM_SetStartMMA())
    e("start");
}

void
fill_mma(unsigned short value)
{
  int i;
  for(i=0;i<NN;i++)
    mma_buf[i]=value;
}

void
uninit_mma()
{
  if(0!=SLM_SetStopMMA())
    e("stop mma");
  if(0!=SLM_SetPowerOff())
    e("set power off");
  if(0!=SLM_Disconnect())
    e("disconnect");
  printf("bye!\n");
}


int
main()
{
  init_lcos();
  init_clara();
  init_mma();

  //  if(0!=SLM_SetStopMMA())
  //  e("stop mma");

  int j;
  for(j=0;j<11;j++){
    fill_mma(((j==4)|(j==5)|(j==6)||(j==8))?90:4096);
    draw_mma(1+j,0,1);
  }
  fill_mma(4096);
  draw_mma(1+12,1,1);
  

  C(PrepareAcquisition());
  // if(0!=SLM_SetStartMMA())
    //    e("start");

    struct timeval tv;    
  suseconds_t old_usec=0;
  time_t old_sec=0;



  for(j=0;j<80;j++){
    gettimeofday(&tv,0);
    
    printf("%3.3g ",
	   (tv.tv_usec/1000.-old_usec/1000.)+(tv.tv_sec/1000000.-old_sec/1000000.));
    
    

    printf("\n");
    frame_count=0;
    sync_mma();
    C(StartAcquisition());
    int i;
    for(i=0;i<12;i++){
      capture_clara();
      draw_lcos();
    }
    C(AbortAcquisition());
    C(FreeInternalMemory());
    old_usec=tv.tv_usec;
    old_sec=tv.tv_sec; 
    
  }
  uninit_clara();
  uninit_lcos();
  uninit_mma();
  return 0;
}
