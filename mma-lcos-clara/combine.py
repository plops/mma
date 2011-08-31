from ctypes import *
from numpy import *
import os
import time
import threading
from OpenGL.GL import *
from OpenGL.GLUT import *
from OpenGL.GLU import *


c=cdll.LoadLibrary("libcombine.so")

GetOldestImage16=c.GetOldestImage16                                                                                                                                      
GetOldestImage16.restype=c_uint                                                                                                                                          
GetOldestImage16.argtypes=[POINTER(c_uint16),c_ulong]

def capture():
    w=412
    h=432 
    a=zeros((w,h),dtype=uint16)
    ret=GetOldestImage16(a.ctypes.data_as(POINTER(c_uint16)),w*h); 
    return a


def init():
    c.init_clara()
    c.init_mma()
    c.StartAcquisition()
    #c.init_lcos()
    
def uninit():
    c.uninit_mma()
    #c.uninit_lcos()
    c.uninit_clara()

def py():
    print time.time()
    #c.SLM_SetStopMMA()
    #c.SLM_SetStartMMA()
    
external_fun=c_int.in_dll(c,"external_fun")
SYNCFUNC = CFUNCTYPE(None)
syncfunc=SYNCFUNC(py)

lcos=threading.Thread(target=(lambda : init()))
#lcos.start()

"""
c_int.in_dll(c,"frame_count").value=8
external_fun.value=addressof(syncfunc)
c.start_lcos_thread()



def sync():
    c.SLM_SetStopMMA()
    c.SLM_SetStartMMA()
    
def py_stop():
    c.SLM_SetStopMMA()


def py_start():
    c.SLM_SetStartMMA()
"""
#

def initgl(w,h):
    glClearColor(0,0,0,0)
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0,w,h,0,-1,1)
    glMatrixMode(GL_MODELVIEW)

old=0
count=0

def drawfun():
    global old, count
    glClearColor(0,0,0,1)
    glClear(GL_COLOR_BUFFER_BIT)
    glLoadIdentity()
    glColor4d(1,1,1,1)
    glTranslated(12,12,0)
    #glScaled(dat.shape[1],dat.shape[2],1)
    glScaled(100,100,1)
    glColor3d(1,1,1,1)
    #time.sleep(1/10.0)
    glutSwapBuffers()
    count=count+1
    if 0==count%10: 
        print 1/(time.time()-old)
    old=time.time()
    
def draw():
    drawfun()

def main():
    global window
    glutInit("")
    glutInitDisplayMode(GLUT_RGBA|GLUT_DOUBLE|GLUT_ALPHA)
    glutInitWindowSize(640,480)
    window=glutCreateWindow("test")
    glutDisplayFunc(draw)
    glutIdleFunc(draw)
    initgl(640,480)
    glutMainLoop()

app=threading.Thread(target=(lambda : main()))

def run():
    os.environ['DISPLAY']=':0'
    os.environ['__GL_SYNC_TO_VBLANK']='1'
    app.start()
