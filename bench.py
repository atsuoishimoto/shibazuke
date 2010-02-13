#!/usr/bin/env python
# coding: utf-8

import gc
gc.disable()
import shibazuke
from cPickle import dumps, loads
import simplejson as json
from time import clock

BENCH_NUM = 10

def bench(func, num=BENCH_NUM):
    start = clock()
    for i in xrange(BENCH_NUM):
            func()
    end = clock()
    print "%-12s  %4.3f[ms]" % (func.__name__, (end-start)*1000/BENCH_NUM)

def setup_int():
    global a, a_pickle, a_shibazuke, a_json
    a = range(1024) * 2**10
    a_pickle = dumps(a)
    a_json = json.dumps(a)
    a_shibazuke = shibazuke.dumps(a)

def setup_str():
    global a, a_pickle, a_shibazuke, a_json
    a = ['a'*(i % 4096) for i in xrange(2**14)]
    a_pickle = dumps(a)
    a_json = json.dumps(a)
    a_shibazuke = shibazuke.dumps(a)


def pickle_dump(): dumps(a)
def pickle_load(): loads(a_pickle)

def json_dump(): json.dumps(a)
def json_load(): json.loads(a_json)

def shibazuke_pack(): shibazuke.dumps(a)
def shibazuke_unpack(): shibazuke.dumps(a_shibazuke)


targets = [
        pickle_dump, pickle_load,
        json_dump, json_load,
        shibazuke_pack, shibazuke_unpack]
import gc
gc.disable()

bytes_suffix = "[bytes]"

print "== Integer =="
setup_int()

print "= Size ="
print "pickle:", len(a_pickle), bytes_suffix
print "json:  ", len(a_json), bytes_suffix
print "shibazuke: ", len(a_shibazuke), bytes_suffix

for t in targets:
    bench(t)

print "== String =="
setup_str()

print "= Size ="
print "pickle:", len(a_pickle), bytes_suffix
print "json:  ", len(a_json), bytes_suffix
print "shibazuke: ", len(a_shibazuke), bytes_suffix

for t in targets:
    bench(t)