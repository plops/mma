from ctypes import *
from numpy import *
import os
import time
import threading

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
    os.environ['DISPLAY']=':0'
    c.init_mma()
    c.StartAcquisition()
    c.init_lcos()
    
def uninit():
    c.uninit_mma()
    c.uninit_lcos()
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

