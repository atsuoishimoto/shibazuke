import struct, sys

cdef extern from "limits.h":
    int CHAR_BIT
    
cdef extern from "Python.h":
    int PyString_CheckExact(object)
    int PyUnicode_CheckExact(object)
    
    
cdef enum:
    INT = 0x00
    # |0000|num |                                    ::: 0 <= num <= 12
    # |0000|1101|.... 8-bit int ....  		 ::: -128 <= num <= 127
    # |0000|1110|.... 16-bit little endian int ....  ::: -32768 <= num <= 32767
    # |0000|1111|.... 32-bit little endian int ....  ::: -2147483648 <= num <= 2147483647

    LONG = 0x10
    # |0010|len |                                    ::: len <= 12
    # |0010|1101|.... 8-bit int ....  		 ::: len <= 127
    # |0010|1110|.... 16-bit little endian int ....  ::: len <= 32767
    # |0010|1111|.... 32-bit little endian int ....  ::: len <= 2147483647

    FLOAT = 0x20
    # |0010|    |.... 64-bit IEEE floating point number...|

    STR = 0x30
    # |0011|len |                                    ::: len <= 12
    # |0011|1101|.... 8-bit int ....  		 ::: len <= 127
    # |0011|1110|.... 16-bit little endian int ....  ::: len <= 32767
    # |0011|1111|.... 32-bit little endian int ....  ::: len <= 2147483647

    USTR = 0x40  # encoded in utf-8
    # |0100|len |                                    ::: len <= 12
    # |0100|1101|.... 8-bit int ....  		 ::: len <= 127
    # |0100|1110|.... 16-bit little endian int ....  ::: len <= 32767
    # |0100|1111|.... 32-bit little endian int ....  ::: len <= 2147483647

    TUPLE = 0x50
    # |0101|len |                                    ::: len <= 12
    # |0101|1101|.... 8-bit int ....  		 ::: len <= 127
    # |0101|1110|.... 16-bit little endian int ....  ::: len <= 32767
    # |0101|1111|.... 32-bit little endian int ....  ::: len <= 2147483647

    LIST = 0x60
    # |0110|len |                                    ::: len <= 12
    # |0110|1101|.... 8-bit int ....  		 ::: len <= 127
    # |0110|1110|.... 16-bit little endian int ....  ::: len <= 32767
    # |0110|1111|.... 32-bit little endian int ....  ::: len <= 2147483647

    DICT = 0x70
    # |0111|len |                                    ::: len <= 12
    # |0111|1101|.... 8-bit int ....  		 ::: len <= 127
    # |0111|1110|.... 16-bit little endian int ....  ::: len <= 32767
    # |0111|1111|.... 32-bit little endian int ....  ::: len <= 2147483647

    REFS = 0xE0
    # |1110|num |                                    ::: num <= 12
    # |1110|1101|.... 8-bit int ....  		 ::: num <= 256
    # |1110|1110|.... 16-bit little endian int ....  ::: num <= 65535
    # |1110|1111|.... 32-bit little endian int ....  ::: num <= 2147483647

    SPECIALS = 0xF0
    # |1111|0000| ::: None
    # |1111|0001| ::: True
    # |1111|0010| ::: False

DEF SZHEADER = "sz\0\0\1"

cdef class Serializer:
    cdef dict _nummap
    cdef dict _strmap
    cdef list _objs
    cdef dict _buildings

    def __init__(self):
        self._nummap = {}
        self._strmap = {}
        self._ustrmap = {}
        self._objs = []
        self._buildings = {}

    def _build_num(self, int flag, long num):
        cdef char c[6]
        
        if 0 <= num <= 12:
            c[0] = <char>(flag | num)
            c[1] = 0
        elif -128 <= num <= 127:
            c[0] = <char>(flag+13)
            c[1] = <char>num
            c[2] = 0
        elif -32768 <= num <= 32767:
            c[0] = <char>(flag+14)
            c[1] = <char>(num & 0xff)
            c[2] = <char>((num >> 8) & 0xff)
            c[3] = 0
        elif (-2147483647-1 <= num) and (num <= 2147483647):
            c[0] = <char>(flag+15)
            c[1] = <char>(num & 0xff)
            c[2] = <char>((num >> 8) & 0xff)
            c[3] = <char>((num >> 16) & 0xff)
            c[4] = <char>((num >> 24) & 0xff)
            c[5] = 0
        else:
            return self._build_big_int(flag, num)
        return c
        
    cdef _build_ref(self, int n):
        s = self._build_num(REFS, n)
        return s

    cdef object _handle_string(self, s):
        n = self._strmap.get(s)
        if n is not None:
            return self._build_ref(n)

        e = self._build_str(STR, s)
        if len(e) <= 4:
            return e

        pos = len(self._objs)
        self._objs.append(e)
        self._strmap[s] = pos
        
        return self._build_ref(pos)

    cdef object _build(self, obj):
        if PyString_CheckExact(obj):
            return self._handle_string(obj)
        
        raise ValueError("Unsupported type")
        
    def dumps(self, obj):
        s = self._build(obj)
        self._objs.append(s)
        return SZHEADER + "".join(self._objs)


