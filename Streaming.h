#ifndef ARDUINO_STREAMING
#define ARDUINO_STREAMING

#include <Arduino.h>
#include "LOG.h"

#define __ST_LOG_LEVEL 3
static LOG _st_logme(__ST_LOG_LEVEL);

// Generic template
template<class T>
inline Print &operator <<(Print &stream, T arg)
{ stream.print(arg); _st_logme.DATA(arg); return stream; }

struct _BASED
{
  long val;
  int base;
  _BASED(long v, int b): val(v), base(b)
  {}
};

#define _HEX(a) _BASED(a, HEX)
#define _DEC(a) _BASED(a, DEC)
#define _OCT(a) _BASED(a, OCT)
#define _BIN(a) _BASED(a, BIN)

// Specialization for class _BASED
// Thanks to Arduino forum user Ben Combee who suggested this
// clever technique to allow for expressions like
// Serial << _HEX(a);

inline Print &operator <<(Print &obj, const _BASED &arg)
{ obj.print(arg.val); return obj; }

#if ARDUINO >= 18
// Specialization for class _FLOAT
// Thanks to Michael Margolis for suggesting a way
// to accommodate Arduino 0018's floating point precision
// feature like this:
// Serial << _FLOAT(gps_latitude, 6); // 6 digits of precision

struct _FLOAT
{
  float val;
  int digits;
  _FLOAT(double v, int d): val(v), digits(d)
  {}
};

inline Print &operator <<(Print &obj, const _FLOAT &arg)
{ obj.print(arg.val, arg.digits); return obj; }
#endif

// Specialization for enum _EndLineCode
// Thanks to Arduino forum user Paul V. who suggested this
// clever technique to allow for expressions like
// Serial << "Hello!" << endl;

enum _EndLineCode { endl };

inline Print &operator <<(Print &obj, _EndLineCode arg)
{ obj.println(); return obj; }

#endif
