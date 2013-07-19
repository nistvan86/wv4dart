library wvtypes;

abstract class StreamedFile {
  int readByte();
  int read(List<num> buffer, int offset, int length);
}

class WavpackConfig {
    int bits_per_sample = 0, bytes_per_sample = 0;
    int num_channels = 0, float_norm_exp = 0;
    int flags = 0, sample_rate = 0, channel_mask = 0;
}

class WavpackHeader {
    String ckID = "    ";  //char ckID[] = new char[4];
    int ckSize = 0;  // was uint32_t in C
    int version = 0;
    int track_no = 0, index_no = 0; // was uchar in C
    int total_samples = 0, block_index = 0, block_samples = 0, flags = 0, crc = 0; // was uint32_t in C
    int status = 0; // 1 means error
}

class Bitstream {
    int end = 0, ptr = 0; // was uchar in c
    int file_bytes = 0, sr = 0;  // was uint32_t in C
    int error = 0, bc = 0;
    StreamedFile file;
    int bitval = 0;
    List<int> buf = new List<int>(Defines.BITSTREAM_BUFFER_SIZE);  // byte[1024] originally
    int buf_index = 0;
}

class entropy_data {
    int slow_level = 0;
    List<int> median = [0,0,0];  // was uint32_t in C, we initialize in order to remove run time errors
    int error_limit = 0; // was uint32_t in C
}

class words_data {
    List<int> bitrate_delta = new List<int>(2); //= new long[2]; // was uint32_t  in C
    List<int> bitrate_acc = new List<int>(2);// = new long[2]; // was uint32_t  in C
    int pend_data = 0, holding_one = 0, zeros_acc = 0;  // was uint32_t  in C
    int holding_zero = 0, pend_count = 0;

    List<entropy_data> c = [new entropy_data() , new entropy_data() ];  // temp_ed1, temp_ed2
}

class Defines
{
    // Change the following value to an even number to reflect the maximum number of samples to be processed
    // per call to WavPackUtils.WavpackUnpackSamples

    static const int SAMPLE_BUFFER_SIZE = 256;
    
    static const int BITSTREAM_BUFFER_SIZE = 1024;        // size of buffer in Bitstream

    static const int FALSE = 0;
    static const int TRUE = 1;

    // or-values for "flags"

    static const int BYTES_STORED = 3;       // 1-4 bytes/sample
    static const int MONO_FLAG  = 4;       // not stereo
    static const int HYBRID_FLAG = 8;       // hybrid mode
    static const int FALSE_STEREO = 0x40000000;      // block is stereo, but data is mono

    static const int SHIFT_LSB = 13;
    static const int SHIFT_MASK = (0x1f << SHIFT_LSB);

    static const int FLOAT_DATA  = 0x80;    // ieee 32-bit floating point data

    static const int SRATE_LSB = 23;
    static const int SRATE_MASK = (0xf << SRATE_LSB);

    static const int FINAL_BLOCK = 0x1000;  // final block of multichannel segment

    static const int MIN_STREAM_VERS = 0x402;       // lowest stream version we'll decode
    static const int MAX_STREAM_VERS = 0x410;       // highest stream version we'll decode

    static const int ID_DUMMY     =    0x0;
    static const int ID_ENCODER_INFO     =    0x1;
    static const int ID_DECORR_TERMS     =    0x2;
    static const int ID_DECORR_WEIGHTS   =    0x3;
    static const int ID_DECORR_SAMPLES   =    0x4;
    static const int ID_ENTROPY_VARS     =    0x5;
    static const int ID_HYBRID_PROFILE   =    0x6;
    static const int ID_SHAPING_WEIGHTS  =    0x7;
    static const int ID_FLOAT_INFO       =    0x8;
    static const int ID_INT32_INFO       =    0x9;
    static const int ID_WV_BITSTREAM     =    0xa;
    static const int ID_WVC_BITSTREAM    =    0xb;
    static const int ID_WVX_BITSTREAM    =    0xc;
    static const int ID_CHANNEL_INFO     =    0xd;

    static const int JOINT_STEREO  =  0x10;    // joint stereo
    static const int CROSS_DECORR  =  0x20;    // no-delay cross decorrelation
    static const int HYBRID_SHAPE  =  0x40;    // noise shape (hybrid mode only)

    static const int INT32_DATA     = 0x100;   // special extended int handling
    static const int HYBRID_BITRATE = 0x200;   // bitrate noise (hybrid mode only)
    static const int HYBRID_BALANCE = 0x400;   // balance noise (hybrid stereo mode only)

    static const int INITIAL_BLOCK  = 0x800;   // initial block of multichannel segment

    static const int FLOAT_SHIFT_ONES = 1;      // bits left-shifted into float = '1'
    static const int FLOAT_SHIFT_SAME = 2;      // bits left-shifted into float are the same
    static const int FLOAT_SHIFT_SENT = 4;      // bits shifted into float are sent literally
    static const int FLOAT_ZEROS_SENT = 8;      // "zeros" are not all real zeros
    static const int FLOAT_NEG_ZEROS  = 0x10;   // contains negative zeros
    static const int FLOAT_EXCEPTIONS = 0x20;   // contains exceptions (inf, nan, etc.)


    static const int ID_OPTIONAL_DATA      =  0x20;
    static const int ID_ODD_SIZE           =  0x40;
    static const int ID_LARGE              =  0x80;

    static const int MAX_NTERMS = 16;
    static const int MAX_TERM = 8;

    static const int MAG_LSB = 18;
    static const int MAG_MASK = (0x1f << MAG_LSB);

    static const int ID_RIFF_HEADER   = 0x21;
    static const int ID_RIFF_TRAILER  = 0x22;
    static const int ID_REPLAY_GAIN   = 0x23;
    static const int ID_CUESHEET      = 0x24;
    static const int ID_CONFIG_BLOCK  = 0x25;
    static const int ID_MD5_CHECKSUM  = 0x26;
    static const int ID_SAMPLE_RATE   = 0x27;

    static const int CONFIG_BYTES_STORED    = 3;       // 1-4 bytes/sample
    static const int CONFIG_MONO_FLAG       = 4;       // not stereo
    static const int CONFIG_HYBRID_FLAG     = 8;       // hybrid mode
    static const int CONFIG_JOINT_STEREO    = 0x10;    // joint stereo
    static const int CONFIG_CROSS_DECORR    = 0x20;    // no-delay cross decorrelation
    static const int CONFIG_HYBRID_SHAPE    = 0x40;    // noise shape (hybrid mode only)
    static const int CONFIG_FLOAT_DATA      = 0x80;    // ieee 32-bit floating point data
    static const int CONFIG_FAST_FLAG       = 0x200;   // fast mode
    static const int CONFIG_HIGH_FLAG       = 0x800;   // high quality mode
    static const int CONFIG_VERY_HIGH_FLAG  = 0x1000;  // very high
    static const int CONFIG_BITRATE_KBPS    = 0x2000;  // bitrate is kbps, not bits / sample
    static const int CONFIG_AUTO_SHAPING    = 0x4000;  // automatic noise shaping
    static const int CONFIG_SHAPE_OVERRIDE  = 0x8000;  // shaping mode specified
    static const int CONFIG_JOINT_OVERRIDE  = 0x10000; // joint-stereo mode specified
    static const int CONFIG_CREATE_EXE      = 0x40000; // create executable
    static const int CONFIG_CREATE_WVC      = 0x80000; // create correction file
    static const int CONFIG_OPTIMIZE_WVC    = 0x100000; // maximize bybrid compression
    static const int CONFIG_CALC_NOISE      = 0x800000; // calc noise in hybrid mode
    static const int CONFIG_LOSSY_MODE      = 0x1000000; // obsolete (for information)
    static const int CONFIG_EXTRA_MODE      = 0x2000000; // extra processing mode
    static const int CONFIG_SKIP_WVX        = 0x4000000; // no wvx stream w/ floats & big ints
    static const int CONFIG_MD5_CHECKSUM    = 0x8000000; // compute & store MD5 signature
    static const int CONFIG_OPTIMIZE_MONO   = 0x80000000; // optimize for mono streams posing as stereo

    static const int MODE_WVC        = 0x1;
    static const int MODE_LOSSLESS   = 0x2;
    static const int MODE_HYBRID     = 0x4;
    static const int MODE_FLOAT      = 0x8;
    static const int MODE_VALID_TAG  = 0x10;
    static const int MODE_HIGH       = 0x20;
    static const int MODE_FAST       = 0x40;

}

class decorr_pass
{
    int term = 0, delta = 0, weight_A = 0, weight_B = 0;
    List<int> samples_A = new List<int>(Defines.MAX_TERM);
    List<int> samples_B = new List<int>(Defines.MAX_TERM);
}

class WavpackStream
{
    WavpackHeader wphdr = new WavpackHeader();
    Bitstream wvbits = new Bitstream();

    words_data w = new words_data();

    int num_terms = 0;
    int mute_error = 0;
    int sample_index = 0, crc = 0; // was uint32_t in C

    int int32_sent_bits = 0, int32_zeros = 0, int32_ones = 0, int32_dups = 0;   // was uchar in C
    int float_flags = 0, float_shift = 0, float_max_exp = 0, float_norm_exp = 0;  // was uchar in C

    //decorr_pass decorr_passes[] = {dp1, dp2, dp3, dp4, dp5, dp6, dp7, dp8, dp9, dp10, dp11, dp12, dp13, dp14, dp15, dp16 };
    List<decorr_pass> decorr_passes = [
      new decorr_pass(), new decorr_pass(), new decorr_pass(), new decorr_pass(), 
      new decorr_pass(), new decorr_pass(), new decorr_pass(), new decorr_pass(), 
      new decorr_pass(), new decorr_pass(), new decorr_pass(), new decorr_pass(), 
      new decorr_pass(), new decorr_pass(), new decorr_pass(), new decorr_pass()
    ];
}

class WavpackContext
{
    WavpackConfig config = new WavpackConfig();
    WavpackStream stream = new WavpackStream();

    List<int> read_buffer = new List<int>(1024); //byte read_buffer[] = new byte[1024];  // was uchar in C
    String error_message = "";
    bool error;

    StreamedFile infile;
    int total_samples = 0, crc_errors = 0, first_flags = 0;    // was uint32_t in C
    int open_flags = 0, norm_offset = 0;
    int reduced_channels = 0;
    int lossy_blocks = 0;
    int status = 0; // 0 ok, 1 error
}

class WavpackMetadata
{
    int byte_length = 0;
    List<int> data;
    int id = 0;   // was uchar in C
    int hasdata = 0;  // 0 does not have data, 1 has data
    int status = 0; // 0 ok, 1 error
    int bytecount = 24;// we use this to determine if we have read all the metadata 
                        // in a block by checking bytecount again the block length
                    // ckSize is block size minus 8. WavPack header is 32 bytes long so we start at 24
}