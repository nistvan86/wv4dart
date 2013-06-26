library wvwavstuff;

// RIFF WAV STUFF
class ChunkHeader
{
    String ckID; //[] = new char[4];
    int ckSize;  // was uint32_t in C
}

class RiffChunkHeader
{
    String ckID; //= new char[4];
    int ckSize;    // was uint32_t in C
    String formType; //[] = new char[4];
}

class WaveHeader
{
    int FormatTag, NumChannels;   // was ushort in C
    int SampleRate, BytesPerSecond;  // was uint32_t in C
    int BlockAlign, BitsPerSample;    // was ushort in C
}

// WAVPACK STUFF
