from ctypes import *
from numpy import *
import os

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


"""
c.init_clara()
os.environ['DISPLAY']=':0'
c.init_lcos()
c.init_mma()
c.StartAcquisition()
"""





