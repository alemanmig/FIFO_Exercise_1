//==============================================================================
// [Filename]     dpi.cpp
// [Project]      -
// [Author]       Ciro Bermudez - cirofabian.bermudez@gmail.com
// [Language]     C++
// [Created]      Dec 2025
// [Modified]     -
// [Description]  DPI (Direct Programming Interface) entry point
// [Notes]        -
// [Status]       stable
// [Revisions]    -
//==============================================================================

#include <iostream>
#include <cstdio>
#include <svdpi.h>

double f(double t, double y) {
  return t*y;
}

double euler_step(double tn, double yn, double h) {
  return yn + h * f(tn, yn);
}

extern "C" double ref_model(double initial_value) {
  double h = 0.2;
  double y0 = initial_value;
  double t = 0.0;
  
  printf("[C++]  t      y\n");
  printf("[C++] %5.2f, %5.2f\n", t, y0);
  for (double tn = 0.0+h; t <= 1.0; t += h) {
    y0 = euler_step(tn, y0, h);
    printf("[C++] %5.2f, %5.2f\n", t, y0);
  }

  return y0;
}

/*
 * SystemVerilog DPI-C Data Type Mappings
 * ========================================
 *
 * BASIC DATA TYPES
 * -------------------------------------------------------------------------------
 * SystemVerilog      | C/C++ (svdpi.h)    | Size   | Notes
 * -------------------------------------------------------------------------------
 * byte               | char               | 8-bit  | Signed
 * shortint           | short int          | 16-bit | Signed
 * int                | int                | 32-bit | Signed
 * longint            | long long          | 64-bit | Signed
 * real               | double             | 64-bit | IEEE 754
 * shortreal          | float              | 32-bit | IEEE 754
 * chandle            | void*              | Ptr    | Opaque handle
 * string             | const char*        | Ptr    | Null-terminated
 * bit                | svBit              | 1-bit  | Unsigned
 * logic              | svLogic            | 1-bit  | 4-state (0,1,X,Z)
 *
 * PACKED ARRAYS (VECTORS)
 * -------------------------------------------------------------------------------
 * SystemVerilog      | C/C++ (svdpi.h)    | Notes
 * -------------------------------------------------------------------------------
 * bit [N:0]          | svBitVecVal*       | 2-state vector
 * logic [N:0]        | svLogicVecVal*     | 4-state vector
 *
 * UNPACKED ARRAYS
 * -------------------------------------------------------------------------------
 * SystemVerilog      | C/C++ (svdpi.h)           | Notes
 * -------------------------------------------------------------------------------
 * Open array []      | const svOpenArrayHandle   | Read-only array
 * Open array []      | svOpenArrayHandle         | Writable array
 *
 * SPECIAL TYPES
 * -------------------------------------------------------------------------------
 * Type               | Usage
 * -------------------------------------------------------------------------------
 * svScope            | Get/set current scope
 * svBitVecVal        | Structure for bit vectors
 * svLogicVecVal      | Structure for logic vectors (aval/bval)
 *
 * EXAMPLE USAGE:
 * -------------------------------------------------------------------------------
 * #include "svdpi.h"
 *
 * extern "C" void my_dpi_func(
 *     int a,              // SystemVerilog: int
 *     long long b,        // SystemVerilog: longint
 *     double c,           // SystemVerilog: real
 *     const char* str,    // SystemVerilog: string
 *     void* handle        // SystemVerilog: chandle
 * );
 */