.. shibazuke documentation master file, created by
   sphinx-quickstart on Fri Feb 12 19:10:53 2010.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

:mod:`shibazuke` --- Fast object serializer for Python
======================================================

.. toctree::
   :maxdepth: 2

:mod:`shibazuke` provides simple and fast object serialization. 
Usually :mod:`shibazuke` generates smaller data than :mod:`picke` or JSON,
and faster on both serialization and de-serialization. :mod:`shibazuke` is
intended to be safely used for interprocess-communications, so hopefully 
de-serializing maliciously crafted data doesn't harm.

Usage
-----

.. function:: dumps(obj)

    Return the shibazuke representation of the object as a string.

.. function:: loads(string)

    Read a shibazuke object hierarchy from a string


Exapmle
-------

Here's simple example of :mod:`shibazuke`::

    >>> import shibazuke
    >>> data = ['abc', {1:(2,3,4)}]
    >>> result = shibazuke.dumps(data)
    >>> data == shibazuke.loads(result)
    True

Limitations
-----------

* Following type of Python objects could be serialized.

    :class:`int`, :class:`long`, :class:`str`, :class:`unicode`, 
    :class:`tuple`, :class:`list`, :class:`dict`

* Number of objects to be serialized is limited to 2147483647.

* Length of serialized string is limited to 2147483647.

* Max depth of object graphs is limited to 100, and circular reference is not
  supported. 

    >>> import shibazuke
    >>> list1 = []
    >>> list2 = [list1]
    >>> list1.append(list2)
    >>> shibazuke.dumps(list1)
    Traceback (most recent call last):
      File "<stdin>", line 1, in <module>
      File "shibazuke.pyx", line 524, in shibazuke.dumps
      File "shibazuke.pyx", line 309, in shibazuke.Serializer.dumps
      File "shibazuke.pyx", line 300, in shibazuke.Serializer._build
      File "shibazuke.pyx", line 246, in shibazuke.Serializer._handle_list
      File "shibazuke.pyx", line 300, in shibazuke.Serializer._build
      File "shibazuke.pyx", line 246, in shibazuke.Serializer._handle_list
      File "shibazuke.pyx", line 300, in shibazuke.Serializer._build
      File "shibazuke.pyx", line 238, in shibazuke.Serializer._handle_list
    ValueError: Circular refecence([[[...]]])

* Objectes can occur multiple times in the object tree to be serialized, 
  but they are de-serialized as differect objects.

    >>> import shibazuke
    >>> list1 = []
    >>> list2 = [list1, list1]
    >>> result = shibazuke.dumps(list2)
    >>> serialized = shibazuke.loads(result)
    >>> serialized[0] is serialized[1]
    False


History
-----------

.. 0.1.1 (2010/3/22)
  Performace improvements.


.. 0.1.0 (2010/2/12)
  Initial release.