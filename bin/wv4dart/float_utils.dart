library wvfloatutils;

import "types.dart";

class FloatUtils
{
    static int read_float_info (WavpackStream wps, WavpackMetadata wpmd)
    {
        int bytecnt = wpmd.byte_length;
        List<int> byteptr = wpmd.data;
        int counter = 0;


        if (bytecnt != 4)
            return Defines.FALSE;

        wps.float_flags = byteptr[counter];
        counter++;
        wps.float_shift = byteptr[counter];
        counter++;
        wps.float_max_exp = byteptr[counter];
        counter++;
        wps.float_norm_exp = byteptr[counter];
  
        return Defines.TRUE;
    }


    static List<int> float_values (WavpackStream wps, List<int> values, int num_values)
    {
        int shift = wps.float_max_exp - wps.float_norm_exp + wps.float_shift;
        int value_counter = 0;

        if (shift > 32)
            shift = 32;
        else if (shift < -32)
            shift = -32;

        while (num_values>0) 
        {
            if (shift > 0)
                values[value_counter] <<= shift;
            else if (shift < 0)
                values[value_counter] >>= -shift;

            if (values[value_counter] > 8388607)
                values[value_counter] = 8388607;
            else if (values[value_counter] < -8388608)
                values[value_counter] = -8388608;

            value_counter++;
            num_values--;
        }

        return values;
    }

}
