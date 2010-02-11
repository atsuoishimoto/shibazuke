import unittest, re

class _base(unittest.TestCase):
    def setUp(self):
        import shibazuke
        module = shibazuke
        
        self.dumps = module.dumps
        self.loads = module.loads
        
    def _test(self, V):
        s = self.dumps(V)
        ret = self.loads(s)
        self.failUnlessEqual(V, ret)
        return s


BORDER_LENS = [12, 127, 32767]

class TestObject(_base):
    def testNone(self):
        self._test(None)
        
    def testInt(self):
        _numbers = [-1, 0, 1, 12, 13, -128, 127, -32768, 
                32767, -2147483648, 2147483647, 2147483648]
        
        for n in _numbers:
            self._test(n)
            self._test(n+1)
            self._test(n+2)
            self._test(n-1)
            self._test(n-2)
        
    def testLong(self):
        for n in BORDER_LENS:
            self._test(long("1"+"0"*(n-2)))
            self._test(long("1"+"0"*(n-1)))
            self._test(long("1"+"0"*(n)))
            self._test(long("1"+"0"*(n+1)))
            self._test(long("1"+"0"*(n+2)))

    def testBool(self):
        self._test(True)
        self._test(False)
        
    def testFloat(self):
        self._test(1.234)
        
    def testNullString(self):
        self._test("")
        
    def testString(self):
        for n in BORDER_LENS:
            self._test("a"*(n-1))
            self._test("a"*(n))
            self._test("a"*(n+1))
        
    def testUnicode(self):
        for n in BORDER_LENS:
            self._test(u"a"*(n-1))
            self._test(u"a"*(n))
            self._test(u"a"*(n+1))
    
    def testNUllUnicode(self):
        self._test(u"")
    
    
class TestTuple(_base):
    def testEmpty(self):
        self._test(())

    def test1(self):
        self._test(('ABCDEFG',))
        self._test((1.0,))
    
    def test3(self):
        self._test((1,2,3))
        self._test(('ABCDEFG','DEFGH', ''))
        self._test((1.0, 2.0, 3.0))
    
    def test4(self):
        for n in BORDER_LENS:
            self._test(tuple(range(0, n-1)))
            self._test(tuple(range(0, n)))
            self._test(tuple(range(0, n+1)))
            
class TestList(_base):
    def testEmpty(self):
        self._test([])

    def test1(self):
        self._test([1,])
        self._test(['ABCDEFG',])
        self._test([1.0,])
    
    def test3(self):
        self._test([1,2,3])
        self._test(['ABCDEFG','DEFGH', ''])
        self._test([1.0, 2.0, 3.0])
    
    def test4(self):
        for n in BORDER_LENS:
            self._test(list(range(0, n-1)))
            self._test(list(range(0, n)))
            self._test(list(range(0, n+1)))

class TestDict(_base):
    def testEmpty(self):
        self._test({})

    def test1(self):
        self._test({1:2})
        self._test({'ABCDEFG':'DEFGHIJ'})
        self._test({1.0:2.0})
    
    def test3(self):
#        self._test({1:2, 2:3, 3:4})
#        self._test({'ABCDEFG':'DEFGHIJ', '012':'345', '678':'9\0'})
        self._test({None:1000000000000L})
        self._test({True:False, None:1000000000000L})

    def test4(self):
        for n in BORDER_LENS:
            self._test(dict((k,k+1) for k in range(0, n-1)))
            self._test(dict((k,k+1) for k in range(0, n)))
            self._test(dict((k,k+1) for k in range(0, n+1)))

class TestRef(_base):
    def testStr(self):
        s = 'AB'
        self._test((s, s, s, s, s))

        s = 'ABCDEFFFFFFFFFFFFFFFFFFFFF'
        self._test((s, s, s, s, s))

    def testUnicode(self):
        s = u'AB'
        self._test((s, s, s, s, s))

        s = u'ABCDEFFFFFFFFFFFFFFFFFFFFF'
        self._test((s, s, s, s, s))

    def testTuple(self):
        tp1 = ('a', 1)
        tp2 = ('b', 2)
        self._test((tp1, tp2, tp1, tp2, tp1))

    def testList(self):
        l1 = ['a', 1]
        l2 = ['b', 2]
        self._test([l1,l2,l1,l2,l1])

    def testDict(self):
        d1 = {'a':1}
        d2 = {'b': 2}
        self._test({1:d1, 2:d2, 3:d1, 4:d2, 5:d1})

class TestNest(_base):
    def testNest(self):
        list1 = [1, 2, 3]
        list2 = ['abc', 'def', list1]
        dict1 = {True:100, 'def':list2}
        tuple1 = (dict1, list1, list2)
        tuple2 = (dict1, list2, list1)
        tuple3 = (list1, dict1, list2)
        tuple4 = (list1, list2, dict1)
        tuple5 = (list2, list1, dict1)
        tuple6 = (list2, dict1, list1)
        dict2 = {(1,2,3):tuple1, (4,5,6):tuple3, (7, 8, 9):'abcdefg'}
        all1 = (list1, list2, dict1, dict2, tuple1, tuple2, tuple3,
                tuple4, tuple5, tuple6)
        all2 = list(all1)
        all3 = (list1, (list2, (dict1, (dict2, (tuple1, (tuple2, (tuple3,
                (tuple4, (tuple5, (tuple6))))))))))

        self._test(tuple1)
        self._test(tuple2)
        self._test(tuple3)
        self._test(tuple4)
        self._test(tuple5)
        self._test(tuple6)
        self._test(dict2)
        self._test(all1)
        self._test(all2)
        self._test(all3)


    def testTupleCircularRef(self):
        def _run():
            l1 = []
            tp1 = (l1,)
            l1.append(tp1)
            
            self._test(tp1)

        self.failUnlessRaises(ValueError, _run)

    def testListCircularRef(self):
        def _run():
            l1 = []
            tp1 = (l1,)
            l1.append(tp1)
            
            self._test(l1)

        self.failUnlessRaises(ValueError, _run)

    def testDictCircularRef(self):
        def _run():
            d1 = {}
            l1 = [d1]
            d1[0]=l1
            l1.append(d1)
            
            self._test(d1)

        self.failUnlessRaises(ValueError, _run)

    def testDeep(self):
        def _run():
            top = l = []
            n = 0
            while 1:
                m = [1]
                l.append(m)
                l = m
                n+=1
                self._test(top)
        self.failUnlessRaises(ValueError, _run)




if __name__ == '__main__':
    unittest.main()


