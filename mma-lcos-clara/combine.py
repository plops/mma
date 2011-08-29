from ctypes import *

libc=cdll.LoadLibrary("libc.so.6")
print libc.time(None)
