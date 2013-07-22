library wv4dart;

import "types.dart";
import "unpack_utils.dart";
import "dartutils.dart";
import "dart:typed_data";

class WavPackUtils
{


    ///////////////////////////// local table storage ////////////////////////////

    static List<int> sample_rates =
    [
        6000, 8000, 9600, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000, 64000, 88200, 96000, 192000
    ];

    ///////////////////////////// executable code ////////////////////////////////


    // This function reads data from the specified stream in search of a valid
    // WavPack 4.0 audio block. If this fails in 1 megabyte (or an invalid or
    // unsupported WavPack block is encountered) then an appropriate message is
    // copied to "error" and NULL is returned, otherwise a pointer to a
    // WavpackContext structure is returned (which is used to call all other
    // functions in this module). This can be initiated at the beginning of a
    // WavPack file, or anywhere inside a WavPack file. To determine the exact
    // position within the file use WavpackGetSampleIndex().  Also,
    // this function will not handle "correction" files, plays only the first
    // two channels of multi-channel files, and is limited in resolution in some
    // large integer or floating point files (but always provides at least 24 bits
    // of resolution).

    static WavpackContext WavpackOpenFileInput(StreamedFile infile)
    {
        WavpackContext wpc = new WavpackContext();
        WavpackStream wps = wpc.stream;

        wpc.infile = infile;
        wpc.total_samples = -1;
        wpc.norm_offset = 0;
        wpc.open_flags = 0;


        // open the source file for reading and store the size

        while (wps.wphdr.block_samples == 0)
        {

            wps.wphdr = read_next_header(wpc.infile, wps.wphdr);

            if (wps.wphdr.status == 1)
            {
                wpc.error_message = "not compatible with this version of WavPack file!";
                wpc.error = true;
                return (wpc);
            }

            if (wps.wphdr.block_samples > 0 && wps.wphdr.total_samples != -1)
            {
                wpc.total_samples = wps.wphdr.total_samples;
            }

            // lets put the stream back in the context

            //wpc.stream = wps;

            if ((UnpackUtils.unpack_init(wpc)) == Defines.FALSE)
            {
                wpc.error = true;
                return wpc;
            }
        } // end of while

        wpc.config.flags = (wpc.config.flags & (~0xff));
        wpc.config.flags = wpc.config.flags | (wps.wphdr.flags & 0xff);

        wpc.config.bytes_per_sample = (wps.wphdr.flags & Defines.BYTES_STORED) + 1;
        wpc.config.float_norm_exp = wps.float_norm_exp;

        wpc.config.bits_per_sample = (wpc.config.bytes_per_sample * 8)
            - ((wps.wphdr.flags & Defines.SHIFT_MASK) >> Defines.SHIFT_LSB);

        if ((wpc.config.flags & Defines.FLOAT_DATA) > 0)
        {
            wpc.config.bytes_per_sample = 3;
            wpc.config.bits_per_sample = 24;
        }

        if (wpc.config.sample_rate == 0)
        {
            if (wps.wphdr.block_samples == 0 || (wps.wphdr.flags & Defines.SRATE_MASK) == Defines.SRATE_MASK)
                wpc.config.sample_rate = 44100;
            else
                wpc.config.sample_rate = sample_rates[(wps.wphdr.flags & Defines.SRATE_MASK)
                    >> Defines.SRATE_LSB];
        }

        if (wpc.config.num_channels == 0)
        {
            if ((wps.wphdr.flags & Defines.MONO_FLAG) > 0)
            {
                wpc.config.num_channels = 1;
            }
            else
            {
                wpc.config.num_channels = 2;
            }

            wpc.config.channel_mask = 0x5 - wpc.config.num_channels;
        }

        if ((wps.wphdr.flags & Defines.FINAL_BLOCK) == 0)
        {
            if ((wps.wphdr.flags & Defines.MONO_FLAG) != 0)
            {
                wpc.reduced_channels = 1;
            }
            else
            {
                wpc.reduced_channels = 2;
            }
        }

        return wpc;
    }

    // This function obtains general information about an open file and returns
    // a mask with the following bit values:

    // MODE_LOSSLESS:  file is lossless (pure lossless only)
    // MODE_HYBRID:  file is hybrid mode (lossy part only)
    // MODE_FLOAT:  audio data is 32-bit ieee floating point (but will provided
    //               in 24-bit integers for convenience)
    // MODE_HIGH:  file was created in "high" mode (information only)
    // MODE_FAST:  file was created in "fast" mode (information only)

    
    static int WavpackGetMode (WavpackContext wpc)
    {
        int mode = 0;
    
        if (null != wpc) 
        {
            if ( (wpc.config.flags & Defines.CONFIG_HYBRID_FLAG) != 0)
                mode |= Defines.MODE_HYBRID;
            else if ((wpc.config.flags & Defines.CONFIG_LOSSY_MODE)==0)
                mode |= Defines.MODE_LOSSLESS;
    
            if (wpc.lossy_blocks != 0)
                mode &= ~Defines.MODE_LOSSLESS;
    
            if ( (wpc.config.flags & Defines.CONFIG_FLOAT_DATA) != 0)
                mode |= Defines.MODE_FLOAT;
    
            if ( (wpc.config.flags & Defines.CONFIG_HIGH_FLAG) != 0)
                mode |= Defines.MODE_HIGH;
    
            if ( (wpc.config.flags & Defines.CONFIG_FAST_FLAG) != 0)
                mode |= Defines.MODE_FAST;
        }
    
        return mode;
    }
    

    // Unpack the specified number of samples from the current file position.
    // Note that "samples" here refers to "complete" samples, which would be
    // 2 longs for stereo files. The audio data is returned right-justified in
    // 32-bit longs in the endian mode native to the executing processor. So,
    // if the original data was 16-bit, then the values returned would be
    // +/-32k. Floating point data will be returned as 24-bit integers (and may
    // also be clipped). The actual number of samples unpacked is returned,
    // which should be equal to the number requested unless the end of fle is
    // encountered or an error occurs.

    static int WavpackUnpackSamples(WavpackContext wpc, List<int> buffer, int samples)
    {
        WavpackStream wps = wpc.stream;
        int samples_unpacked = 0, samples_to_unpack;
        int num_channels = wpc.config.num_channels;
        int bcounter = 0;

        List<int> temp_buffer = new List<int>.filled(Defines.SAMPLE_BUFFER_SIZE, 0);
        int buf_idx = 0;
        int bytes_returned = 0;

        while (samples > 0)
        {
            if (wps.wphdr.block_samples == 0 || (wps.wphdr.flags & Defines.INITIAL_BLOCK) == 0
                || wps.sample_index >= wps.wphdr.block_index
                + wps.wphdr.block_samples)
            {
                wps.wphdr = read_next_header(wpc.infile, wps.wphdr);

                if (wps.wphdr.status == 1)
                    break;

                if (wps.wphdr.block_samples == 0 || wps.sample_index == wps.wphdr.block_index)
                {
                    if ((UnpackUtils.unpack_init(wpc)) == Defines.FALSE)
                        break;
                }
            }

            if (wps.wphdr.block_samples == 0 || (wps.wphdr.flags & Defines.INITIAL_BLOCK) == 0
                || wps.sample_index >= wps.wphdr.block_index
                + wps.wphdr.block_samples)
                continue;

            if (wps.sample_index < wps.wphdr.block_index)
            {
                samples_to_unpack = wps.wphdr.block_index - wps.sample_index;

                if (samples_to_unpack > samples)
                    samples_to_unpack = samples;

                wps.sample_index += samples_to_unpack;
                samples_unpacked += samples_to_unpack;
                samples -= samples_to_unpack;

                if (wpc.reduced_channels > 0)
                    samples_to_unpack *= wpc.reduced_channels;
                else
                    samples_to_unpack *= num_channels;

                bcounter = buf_idx;
                while (samples_to_unpack > 0)
                {
                    buffer[bcounter] = 0;
                    bcounter++;
                    samples_to_unpack--;
                }
                buf_idx = bcounter;

                continue;
            }

            samples_to_unpack = wps.wphdr.block_index + wps.wphdr.block_samples - wps.sample_index;

            if (samples_to_unpack > samples)
                samples_to_unpack = samples;

            UnpackUtils.unpack_samples(wpc, temp_buffer, samples_to_unpack);

            if (wpc.reduced_channels > 0)
                bytes_returned = (samples_to_unpack * wpc.reduced_channels);
            else
                bytes_returned = (samples_to_unpack * num_channels);

            //System.arraycopy(temp_buffer, 0, buffer, buf_idx, bytes_returned);

            buffer.setRange(buf_idx, buf_idx+bytes_returned, temp_buffer, 0);

            buf_idx += bytes_returned;

            samples_unpacked += samples_to_unpack;
            samples -= samples_to_unpack;

            if (wps.sample_index == wps.wphdr.block_index + wps.wphdr.block_samples)
            {
                if (UnpackUtils.check_crc_error(wpc) > 0)
                    wpc.crc_errors++;
            }

            if (wps.sample_index == wpc.total_samples)
                break;
        }

        return (samples_unpacked);
    }


    // Get total number of samples contained in the WavPack file, or -1 if unknown

    static int WavpackGetNumSamples(WavpackContext wpc)
    {
        // -1 would mean an unknown number of samples

        if( null != wpc)
        {
            return (wpc.total_samples);
        }
        else
        {
            return -1;
        }
    }


    // Get the current sample index position, or -1 if unknown
 
    static int WavpackGetSampleIndex (WavpackContext wpc)
    {
        if (null != wpc)
            return wpc.stream.sample_index;
    
        return -1;
    }
    


    // Get the number of errors encountered so far

    static int WavpackGetNumErrors(WavpackContext wpc)
    {
        if( null != wpc)
        {
            return wpc.crc_errors;
        }
        else
        {
            return 0;
        }
    }


    // return if any uncorrected lossy blocks were actually written or read

    
    static int WavpackLossyBlocks (WavpackContext wpc)
    {
        if(null != wpc)
        {
             return wpc.lossy_blocks;
        }
        else
        {
            return 0;
        }
    }
    


    // Returns the sample rate of the specified WavPack file

    static int WavpackGetSampleRate(WavpackContext wpc)
    {
        if ( null != wpc && wpc.config.sample_rate != 0)
        {
            return wpc.config.sample_rate;
        }
        else
        {
            return 44100;
        }
    }


    // Returns the number of channels of the specified WavPack file. Note that
    // this is the actual number of channels contained in the file, but this
    // version can only decode the first two.

    static int WavpackGetNumChannels(WavpackContext wpc)
    {
        if ( null != wpc && wpc.config.num_channels != 0)
        {
            return wpc.config.num_channels;
        }
        else
        {
            return 2;
        }
    }


    // Returns the actual number of valid bits per sample contained in the
    // original file, which may or may not be a multiple of 8. Floating data
    // always has 32 bits, integers may be from 1 to 32 bits each. When this
    // value is not a multiple of 8, then the "extra" bits are located in the
    // LSBs of the results. That is, values are right justified when unpacked
    // into longs, but are left justified in the number of bytes used by the
    // original data.

    static int WavpackGetBitsPerSample(WavpackContext wpc)
    {
        if (null != wpc && wpc.config.bits_per_sample != 0)
        {
            return wpc.config.bits_per_sample;
        }
        else
        {
            return 16;
        }
    }


    // Returns the number of bytes used for each sample (1 to 4) in the original
    // file. This is required information for the user of this module because the
    // audio data is returned in the LOWER bytes of the long buffer and must be
    // left-shifted 8, 16, or 24 bits if normalized longs are required.

    static int WavpackGetBytesPerSample(WavpackContext wpc)
    {
        if ( null != wpc && wpc.config.bytes_per_sample != 0)
        {
            return wpc.config.bytes_per_sample;
        }
        else
        {
            return 2;
        }
    }


    // This function will return the actual number of channels decoded from the
    // file (which may or may not be less than the actual number of channels, but
    // will always be 1 or 2). Normally, this will be the front left and right
    // channels of a multi-channel file.

    static int WavpackGetReducedChannels(WavpackContext wpc)
    {
        if (null != wpc && wpc.reduced_channels != 0)
        {
            return wpc.reduced_channels;
        }
        else if (null != wpc && wpc.config.num_channels != 0)
        {
            return wpc.config.num_channels;
        }
        else
        {
            return 2;
        }
    }

    // Read from current file position until a valid 32-byte WavPack 4.0 header is
    // found and read into the specified pointer. If no WavPack header is found within 1 meg,
    // then an error is returned. No additional bytes are read past the header. 

    static WavpackHeader read_next_header(StreamedFile infile, WavpackHeader wphdr)
    {
        List<int> buffer = new List<int>(32); // 32 is the size of a WavPack Header
        List<int> temp = new List<int>(32);

        int bytes_skipped = 0;
        int bleft = 0; // bytes left in buffer
        int counter = 0;
        int i = 0;

        while (true)
        {
            for (i = 0; i < bleft; i++)
            {
                buffer[i] = buffer[32 - bleft + i];
            }

            counter = 0;

            try
            {
                if (infile.read(temp, 0, 32 - bleft) != 32 - bleft)
                {
                    wphdr.status = 1;
                    return wphdr;
                }
            }
            catch (e)
            {
                wphdr.status = 1;
                return wphdr;
            }

            for (i = 0; i < 32 - bleft; i++)
            {
                buffer[bleft + i] = temp[i];
            }

            bleft = 32;

            if ((new String.fromCharCodes(buffer.getRange(0,4)) == "wvpk")
                && (buffer[4] & 1) == 0 && buffer[6] < 16 && buffer[7] == 0 && buffer[9] == 4
                && buffer[8] >= (Defines.MIN_STREAM_VERS & 0xff) && buffer[8] <= (Defines.MAX_STREAM_VERS & 0xff))
            {
                wphdr.ckID="wvpk";

                wphdr.ckSize = WvDartUtils.getS32Int(buffer, 4);

                wphdr.version = (buffer[9] << 8);
                wphdr.version += (buffer[8]);

                wphdr.track_no = buffer[10];
                wphdr.index_no = buffer[11];

                wphdr.total_samples = WvDartUtils.getS32Int(buffer, 12);
                wphdr.block_index = WvDartUtils.getS32Int(buffer, 16);
                wphdr.block_samples = WvDartUtils.getS32Int(buffer, 20);
                wphdr.flags = WvDartUtils.getS32Int(buffer, 24);
                wphdr.crc = WvDartUtils.getS32Int(buffer, 28);
                
                wphdr.status = 0;

                return wphdr;
            }
            else
            {
                counter++;
                bleft--;
            }

            while (bleft > 0 && buffer[counter] != 119)    // 119 is letter 'w'
            {
                counter++;
                bleft--;
            }

            bytes_skipped = bytes_skipped + counter;

            if (bytes_skipped > 1048576)
            {
                wphdr.status = 1;
                return wphdr;
            }
        }
    }
}