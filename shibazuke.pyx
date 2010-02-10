import struct, sys


	

cdef extern from "util.h":
    enum:
        LONGINT_BUFSIZE
    
cdef extern from "limits.h":
    enum:
        CHAR_BIT
    
cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *, Py_ssize_t charlen)
    int PyString_AsStringAndSize(object, char **, Py_ssize_t *) except -1
    object PyUnicode_FromStringAndSize(char *u, Py_ssize_t size)
    
    int PyBool_Check(object)
    int PyInt_CheckExact(object)
    int PyLong_CheckExact(object)
    int PyFloat_CheckExact(object)
    int PyString_CheckExact(object)
    int PyUnicode_CheckExact(object)
    int PyTuple_CheckExact(object)
    int PyList_CheckExact(object)
    int PyDict_CheckExact(object)
    int _PyFloat_Pack8(double x, unsigned char *p, int le) except -1
    double _PyFloat_Unpack8(unsigned char *p, int le)
    double PyFloat_AS_DOUBLE(object) 
    object PyFloat_FromDouble(double v) 
    object PyInt_FromString(char *, char**, int)
    object PyList_GET_ITEM(object list, Py_ssize_t i) 
    void Py_XINCREF(object)
    
cdef enum:
    INT = 0x00
    # |0000|num |                                    ::: 0 <= num <= 12
    # |0000|1101|.... 8-bit int ....  		 ::: -128 <= num <= 127
    # |0000|1110|.... 16-bit little endian int ....  ::: -32768 <= num <= 32767
    # |0000|1111|.... 32-bit little endian int ....  ::: -2147483647 <= num <= 2147483647

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
    cdef dict _ustrmap
    cdef list _objs
    cdef dict _buildings

    def __init__(self):
        self._nummap = {}
        self._strmap = {}
        self._ustrmap = {}
        self._objs = []
        self._buildings = {}

    cdef object _build_num(self, int flag, long num):
        cdef char c[6]
        cdef Py_ssize_t tlen
        
        if 0 <= num <= 12:
            c[0] = <char>(flag | num)
            tlen = 1
            
        elif -128 <= num <= 127:
            c[0] = <char>(flag+13)
            c[1] = <char>num
            tlen = 2

        elif -32768 <= num <= 32767:
            c[0] = <char>(flag+14)
            c[1] = <char>(num & 0xff)
            c[2] = <char>((num >> 8) & 0xff)
            tlen = 3

        elif (-2147483647 <= num) and (num <= 2147483647):
            c[0] = <char>(flag+15)
            c[1] = <char>(num & 0xff)
            c[2] = <char>((num >> 8) & 0xff)
            c[3] = <char>((num >> 16) & 0xff)
            c[4] = <char>((num >> 24) & 0xff)
            tlen = 5
        else:
            raise ValueError("Unsupported int value")
            
        return PyString_FromStringAndSize(c, tlen)

    cdef object _build_long(self, int flag, object l):
        cdef object s
        s = str(l)
        return self._build_num(flag, len(s))+s


    cdef object _build_str(self, int flag, s):
        return self._build_num(flag, len(s))+s
    
    cdef _build_ref(self, int n):
        s = self._build_num(REFS, n)
        return s

    cdef object _handle_int(self, object i):
        cdef long v
        v = i
        
        if -2147483647 <= v <= 2147483647:
            return self._build_num(INT, v)
        else:
            return self._handle_long(i)
    
    cdef object _handle_long(self, object l):
        n = self._nummap.get(l)
        if n is not None:
            return self._build_ref(n)
            
        ret = self._build_long(LONG, l)
        if len(ret) <= 4:
            # num is small. don't use object table.
            return ret

        pos = len(self._objs)
        self._objs.append(ret)
        self._nummap[l] = pos
        return self._build_ref(pos)
        
    cdef object _handle_float(self, f):
        cdef double d
        cdef char buf[9]
        
        buf[0] = 0x20
        d = PyFloat_AS_DOUBLE(f)
        _PyFloat_Pack8(d, <unsigned char*>&(buf[1]), 1)

        return PyString_FromStringAndSize(buf, 9)
        
    cdef object _handle_string(self, object s):
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

    cdef _handle_unicode(self, s):
        n = self._ustrmap.get(s)
        if n is not None:
            return self._build_ref(n)

        e = s.encode("utf-8")
        e = self._build_str(USTR, e)
        if len(e) <= 4:
            return e

        pos = len(self._objs)
        self._objs.append(e)
        self._ustrmap[s] = pos

        return self._build_ref(pos)

    cdef object _handle_tuple(self, t):
        cdef list subitems

        objid = id(t)
        if objid in self._buildings:
            raise ValueError('Circular refecence(%s)' % `t`)

        self._buildings[objid] = None
        subitems = []
        for item in t:
            subitems.append(self._build(item))

        s = self._build_num(TUPLE, len(t)) + "".join(subitems)

        pos = len(self._objs)
        self._objs.append(s) 
        del self._buildings[objid]

        return self._build_ref(pos)

    cdef _handle_list(self, list t):
        cdef list subitems

        objid = id(t)
        if objid in self._buildings:
            raise ValueError('Circular refecence(%s)' % `t`)

        self._buildings[objid] = None
        subitems = []
        for item in t:
            subitems.append(self._build(item))

        s = self._build_num(LIST, len(t)) + "".join(subitems)

        pos = len(self._objs)
        self._objs.append(s) 
        del self._buildings[objid]

        return self._build_ref(pos)

    cdef _handle_dict(self, dict d):
        cdef list subitems

        objid = id(d)
        if objid in self._buildings:
            raise ValueError('Circular refecence(%s)' % d)

        self._buildings[objid] = None
        subitems = []
        for k, v in d.iteritems():
            subitems.append(self._build(k))
            subitems.append(self._build(v))
            
        s = self._build_num(DICT, len(d)) + "".join(subitems)

        pos = len(self._objs)
        self._objs.append(s) 
        del self._buildings[objid]

        return self._build_ref(pos)

    def _handle_none(self, v):
        return chr(SPECIALS+0)
        
    def _handle_bool(self, v):
        if v:
            return chr(SPECIALS+1)
        else:
            return chr(SPECIALS+2)
            
    cdef object _build(self, obj):
        if PyBool_Check(obj):
            return self._handle_bool(obj)
        elif PyString_CheckExact(obj):
            return self._handle_string(obj)
        elif PyUnicode_CheckExact(obj):
            return self._handle_unicode(obj)
        elif PyInt_CheckExact(obj):
            return self._handle_int(obj)
        elif PyLong_CheckExact(obj):
            return self._handle_long(obj)
        elif PyFloat_CheckExact(obj):
            return self._handle_float(obj)
        elif PyTuple_CheckExact(obj):
            return self._handle_tuple(obj)
        elif PyList_CheckExact(obj):
            return self._handle_list(obj)
        elif PyDict_CheckExact(obj):
            return self._handle_dict(obj)
        elif obj is None:
            return self._handle_none(obj)

        raise ValueError("Unsupported type")
        
    def dumps(self, obj):
        s = self._build(obj)
        self._objs.append(s)
        return SZHEADER + "".join(self._objs)


cdef class Loader:
    cdef list _objs
    cdef char *src
    cdef Py_ssize_t curpos, endpos

    def __init__(self):
        self._objs = []

    cdef long _load_num(self) except *:
        cdef long n, ret

        if self.curpos >= self.endpos:
            raise ValueError("Invalid data")

        n = self.src[self.curpos] & 0x0f
        if n <= 12:
            ret = n
            self.curpos = self.curpos + 1
        elif n == 13:
            if self.curpos+2 > self.endpos:
                raise ValueError("Invalid data")
            ret = self.src[self.curpos+1]
            self.curpos = self.curpos + 2
        elif n == 14:
            if self.curpos+3 > self.endpos:
                raise ValueError("Invalid data")
            ret = self.src[self.curpos+2]
            ret = (ret << 8) | (self.src[self.curpos+1] & 0xff)
            self.curpos = self.curpos + 3
        elif n == 15:
            if self.curpos+5 > self.endpos:
                raise ValueError("Invalid data")
            ret = self.src[self.curpos+4]
            ret = (ret << 8) | (self.src[self.curpos+3] & 0xff)
            ret = (ret << 8) | (self.src[self.curpos+2] & 0xff)
            ret = (ret << 8) | (self.src[self.curpos+1] & 0xff)
            self.curpos = self.curpos + 5
        else:
            raise ValueError("Invalid data")
        return ret

    cdef _handle_num(self):
        val = self._load_num()
        return val
        
    cdef _handle_long(self):
        cdef long slen
        cdef char *end
        
        slen = self._load_num()
        if slen < 0:
            raise ValueError("Invalid data")
        if self.curpos + slen > self.endpos:
            raise ValueError("Invalid data")

        s = PyString_FromStringAndSize(self.src+self.curpos, slen)
        val = PyInt_FromString(s, &end, 10)
        self.curpos = self.curpos + slen
        return val
        
    cdef _handle_str(self):
        cdef long slen
        
        slen = self._load_num()
        if slen < 0:
            raise ValueError("Invalid data")
        if self.curpos + slen > self.endpos:
            raise ValueError("Invalid data")
        
        ret = PyString_FromStringAndSize(self.src+self.curpos, slen)
        self.curpos = self.curpos + slen
        
        return ret
        
    cdef object _handle_ustr(self):
        cdef long slen
        
        slen = self._load_num()
        if slen < 0:
            raise ValueError("Invalid data")
        if self.curpos + slen > self.endpos:
            raise ValueError("Invalid data")
        
        ret = PyUnicode_FromStringAndSize(self.src+self.curpos, slen)
        self.curpos = self.curpos + slen
        return ret

    cdef _handle_float(self):
        cdef double d
        if self.curpos+9 > self.endpos:
            raise ValueError("Invalid data")

        d = _PyFloat_Unpack8(<unsigned char *>(self.src+self.curpos+1), 1)
        
        self.curpos += 9
        return PyFloat_FromDouble(d)
    
    cdef _handle_tuple(self):
        cdef long nitems, i
        cdef list items

        nitems = self._load_num()
        if nitems < 0:
            raise ValueError("Invalid data")
        
        items = []
        for 0 <= i < nitems:
            val = self._load()
            items.append(val)
        
        ret = tuple(items)
        return ret

    cdef _handle_list(self):
        cdef long nitems, i
        cdef list items
        
        nitems = self._load_num()
        if nitems < 0:
            raise ValueError("Invalid data")
        
        items = []
        for 0 <= i < nitems:
            val = self._load()
            items.append(val)
        return items

    cdef _handle_dict(self):
        cdef long nitems
        cdef dict d
        
        nitems = self._load_num()
        if nitems < 0:
            raise ValueError("Invalid data")
        
        d = {}
        for n in range(nitems):
            key = self._load()
            if PyString_CheckExact(key):
                key = intern(key)
            val = self._load()
            d[key] = val
        return d

    cdef _handle_refs(self):
        cdef long n

        n = self._load_num()
        val = PyList_GET_ITEM(self._objs, n)
        Py_XINCREF(val)
        return val

    cdef _handle_specials(self):
        cdef int v
        v = self.src[self.curpos] & 0x0f
        self.curpos = self.curpos + 1
        if v == 0:
            return None
        elif v == 1:
            return True
        elif v == 2:
            return False

        raise ValueError("Invalid data")
        
    cdef object _load(self):
        cdef int flag
        
        if self.curpos >= self.endpos:
            raise ValueError("Invalid data")

        flag = self.src[self.curpos] & 0xf0
        
        if flag == INT:
            return self._handle_num()
        elif flag == LONG:
            return self._handle_long()
        elif flag == STR:
            return self._handle_str()
        elif flag == USTR:
            return self._handle_ustr()
        elif flag == FLOAT:
            return self._handle_float()
        elif flag == TUPLE:
            return self._handle_tuple()
        elif flag == LIST:
            return self._handle_list()
        elif flag == DICT:
            return self._handle_dict()
        elif flag == REFS:
            return self._handle_refs()
        elif flag == SPECIALS:
            return self._handle_specials()
        else:
            raise ValueError("Invalid token: %x" % flag)

    def loads(self, s):
        if not s.startswith(SZHEADER):
            raise ValueError("Invalid header")
        
        self.curpos = len(SZHEADER)
        PyString_AsStringAndSize(s, &(self.src), &(self.endpos))
        
        while self.curpos < self.endpos:
            val = self._load()
            self._objs.append(val)
        return self._objs[-1]


def dumps(s):
    return Serializer().dumps(s)

def loads(s):
    return Loader().loads(s)
