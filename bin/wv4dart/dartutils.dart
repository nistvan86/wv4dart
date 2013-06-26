library wvdartutils;

import "dart:typed_data";

class WvDartUtils {
  static int getS32Int(List<int> buffer, int from) {
    final resultList = new Int8List(4)
    ..setRange(0, 4, buffer, from);
    return resultList.asByteArray().getInt32(0);
  }
  
  static int getS16Int(List<int> buffer, int from) {
    final resultList = new Int8List(2)
    ..setRange(0, 2, buffer, from);
    return resultList.asByteArray().getInt16(0);
  }
  
  static int getS16IntFromBytes(int high8Bit, int low8Bit) {
    final resultList = new Int8List(2)
    ..[0] = low8Bit
    ..[1] = high8Bit;
    return resultList.asByteArray().getInt16(0);
  }
}