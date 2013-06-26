import "wv4dart/types.dart";
import "wv4dart/wavpack_utils.dart";
import "wv4dart/riff_stuff.dart";
import "dart:io";

class RandomAccessWavPackFile extends StreamedFile {
  RandomAccessFile _file;
  
  RandomAccessWavPackFile(RandomAccessFile file) {
    _file = file;
  }
  
  int readByte() {
    return _file.readByteSync();
  }
  
  int read(List<num> buffer, int offset, int length) {
    return _file.readListSync(buffer, offset, length);
  }
}

void main() {
  RandomAccessFile input = new File("input.wv").openSync();
  RandomAccessWavPackFile wavPackFile = new RandomAccessWavPackFile(input);
  WavpackContext context = WavPackUtils.WavpackOpenFileInput(wavPackFile);
  
  if (context.error)
  {
    print("Sorry an error has occured");
    print(context.error_message);
    exit(-1);
  }

  int num_channels = WavPackUtils.WavpackGetReducedChannels(context);

  print("The wavpack file has ${num_channels} channels");
  int total_samples = WavPackUtils.WavpackGetNumSamples(context);
  print("The wavpack file has ${total_samples} samples");
  int bps = WavPackUtils.WavpackGetBytesPerSample(context);
  print("The wavpack file has ${bps} bytes per sample");
  
  RiffChunkHeader myRiffChunkHeader = new RiffChunkHeader();
  myRiffChunkHeader.ckID = "RIFF";
  myRiffChunkHeader.ckSize = total_samples * num_channels * bps + 8 * 2 + 16 + 4;
  myRiffChunkHeader.formType = "WAVE";
  
  ChunkHeader formatChunkHeader = new ChunkHeader();
  formatChunkHeader.ckID = "fmt ";
  formatChunkHeader.ckSize = 16;
  
  WaveHeader waveHeader = new WaveHeader();
  waveHeader.FormatTag = 1;
  waveHeader.NumChannels = num_channels;
  waveHeader.SampleRate = WavPackUtils.WavpackGetSampleRate(context);
  waveHeader.BlockAlign = num_channels * bps;
  waveHeader.BytesPerSecond = waveHeader.SampleRate * waveHeader.BlockAlign;
  waveHeader.BitsPerSample = WavPackUtils.WavpackGetBitsPerSample(context);
  
  ChunkHeader dataChunkHeader = new ChunkHeader();
  dataChunkHeader.ckID = "data";
  dataChunkHeader.ckSize = total_samples * num_channels * bps;
  
  RandomAccessFile output = new File("output.wav").openSync(FileMode.WRITE);
  output.writeString(myRiffChunkHeader.ckID);
  output.writeByte(myRiffChunkHeader.ckSize);
  output.writeByte(myRiffChunkHeader.ckSize >> 8);
  output.writeByte(myRiffChunkHeader.ckSize >> 16);
  output.writeByte(myRiffChunkHeader.ckSize >> 24);
  output.writeString(myRiffChunkHeader.formType);
  
  output.writeString(formatChunkHeader.ckID);
  output.writeByte(formatChunkHeader.ckSize);
  output.writeByte(formatChunkHeader.ckSize >> 8);
  output.writeByte(formatChunkHeader.ckSize >> 16);
  output.writeByte(formatChunkHeader.ckSize >> 24);
  
  output.writeByte(waveHeader.FormatTag);
  output.writeByte(waveHeader.FormatTag >> 8);
  
  output.writeByte(waveHeader.NumChannels);
  output.writeByte(waveHeader.NumChannels >> 8);
  
  output.writeByte(waveHeader.SampleRate);
  output.writeByte(waveHeader.SampleRate >> 8);
  output.writeByte(waveHeader.SampleRate >> 16);
  output.writeByte(waveHeader.SampleRate >> 24);
  
  output.writeByte(waveHeader.BytesPerSecond);
  output.writeByte(waveHeader.BytesPerSecond >> 8);
  output.writeByte(waveHeader.BytesPerSecond >> 16);
  output.writeByte(waveHeader.BytesPerSecond >> 24);
  
  output.writeByte(waveHeader.BlockAlign);
  output.writeByte(waveHeader.BlockAlign >> 8);
  
  output.writeByte(waveHeader.BitsPerSample);
  output.writeByte(waveHeader.BitsPerSample >> 8);
  
  output.writeString(dataChunkHeader.ckID);
  
  output.writeByte(dataChunkHeader.ckSize);
  output.writeByte(dataChunkHeader.ckSize >> 8);
  output.writeByte(dataChunkHeader.ckSize >> 16);
  output.writeByte(dataChunkHeader.ckSize >> 24);
  
  List<int> temp_buffer = new List<int>.filled(Defines.SAMPLE_BUFFER_SIZE, 0);
  List<int> pcm_buffer = new List<int>.filled(4* Defines.SAMPLE_BUFFER_SIZE, 0);
  
  int total_unpacked_samples = 0;
  
  while (true)
  {
    int samples_unpacked = WavPackUtils.WavpackUnpackSamples(context, temp_buffer, Defines.SAMPLE_BUFFER_SIZE ~/ num_channels);
    total_unpacked_samples += samples_unpacked;

    if (samples_unpacked > 0)
    {
      samples_unpacked = samples_unpacked * num_channels;

      pcm_buffer = format_samples(bps, temp_buffer, samples_unpacked);
      output.writeList(pcm_buffer, 0, samples_unpacked * bps);
    }

    if (samples_unpacked == 0)
      break;

  } // end of while
  
  output.closeSync();
  input.closeSync();
  
  
}

List<int> format_samples(int bps, List<int> src, int samcnt)
{
  int temp;
  int counter = 0;
  int counter2 = 0;
  List<int> dst = new List<int>(4 * Defines.SAMPLE_BUFFER_SIZE);

  switch (bps)
  {
    case 1:
      while (samcnt > 0)
      {
        dst[counter] = (0x00FF & (src[counter] + 128));
        counter++;
        samcnt--;
      }
      break;

    case 2:
      while (samcnt > 0)
      {
        temp = src[counter2];
        dst[counter] = temp;
        counter++;
        dst[counter] = temp >> 8;
        counter++;
        counter2++;
        samcnt--;
      }

      break;

    case 3:
      while (samcnt > 0)
      {
        temp = src[counter2];
        dst[counter] = temp;
        counter++;
        dst[counter] = temp >> 8;
        counter++;
        dst[counter] = temp >> 16;
        counter++;
        counter2++;
        samcnt--;
      }

      break;

    case 4:
      while (samcnt > 0)
      {
        temp = src[counter2];
        dst[counter] = temp;
        counter++;
        dst[counter] = temp >> 8;
        counter++;
        dst[counter] = temp >> 16;
        counter++;
        dst[counter] = temp >> 24;
        counter++;
        counter2++;
        samcnt--;
      }

      break;
  }

  return dst;
}