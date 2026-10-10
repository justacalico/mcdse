import 'dart:math';
import 'dart:typed_data';

/// Ported from `TextureDecoder.cs` — decodes cooked UE4 texture pixels
/// (DXT1/DXT5/BC4/BC5/B8G8R8A8/G8) to RGBA8.
abstract final class TextureDecoder {
  static Uint8List decodeImage(
      Uint8List data, int width, int height, int depth, String pixelFormat) {
    switch (pixelFormat) {
      case 'PF_DXT5':
        return _decodeDXT5(data, width, height, depth);
      case 'PF_DXT1':
        return _decodeDXT1(data, width, height, depth);
      case 'PF_B8G8R8A8':
        // Swap BGRA → RGBA.
        final out = Uint8List(width * height * 4);
        for (var i = 0; i < width * height; i++) {
          out[i * 4] = data[i * 4 + 2];
          out[i * 4 + 1] = data[i * 4 + 1];
          out[i * 4 + 2] = data[i * 4];
          out[i * 4 + 3] = data[i * 4 + 3];
        }
        return out;
      case 'PF_BC5':
        return _decodeBC5(data, width, height);
      case 'PF_BC4':
        return _decodeBC4(data, width, height);
      case 'PF_G8':
        final out = Uint8List(width * height * 4);
        for (var i = 0; i < width * height; i++) {
          out[i * 4] = data[i];
          out[i * 4 + 1] = data[i];
          out[i * 4 + 2] = data[i];
          out[i * 4 + 3] = 0xFF;
        }
        return out;
      default:
        throw UnimplementedError('Cannot decode $pixelFormat format');
    }
  }

  static int _pixelLoc(int width, int x, int y, int bpp, int off) =>
      (y * width + x) * bpp + off;

  // ---- DXT1 ----

  static Uint8List _decodeDXT1(
      Uint8List inp, int width, int height, int depth) {
    const bpp = 4;
    final bps = width * bpp;
    final sizeOfPlane = bps * height;
    final rawData = Uint8List(depth * sizeOfPlane + height * bps + width * bpp);
    final data = ByteData.sublistView(inp);

    final colours =
        List.generate(4, (_) => [0, 0, 0, 0xFF]); // r,g,b,a
    var pos = 0;
    for (var z = 0; z < depth; z++) {
      for (var y = 0; y < height; y += 4) {
        for (var x = 0; x < width; x += 4) {
          if (pos + 8 > inp.length) return rawData;
          final colour0 = data.getUint16(pos, Endian.little);
          final colour1 = data.getUint16(pos + 2, Endian.little);
          _dxtcReadColor(colour0, colours[0]);
          _dxtcReadColor(colour1, colours[1]);
          final bitmask = data.getUint32(pos + 4, Endian.little);
          pos += 8;

          if (colour0 > colour1) {
            for (var c = 0; c < 3; c++) {
              colours[2][c] = (2 * colours[0][c] + colours[1][c] + 1) ~/ 3;
              colours[3][c] = (colours[0][c] + 2 * colours[1][c] + 1) ~/ 3;
            }
            colours[2][3] = 0xFF;
            colours[3][3] = 0xFF;
          } else {
            for (var c = 0; c < 3; c++) {
              colours[2][c] = (colours[0][c] + colours[1][c]) ~/ 2;
              colours[3][c] = (colours[0][c] + 2 * colours[1][c] + 1) ~/ 3;
            }
            colours[2][3] = 0xFF;
            colours[3][3] = 0x00;
          }

          var k = 0;
          for (var j = 0; j < 4; j++) {
            for (var i = 0; i < 4; i++, k++) {
              final select = (bitmask & (0x03 << (k * 2))) >> (k * 2);
              final col = colours[select];
              if (((x + i) < width) && ((y + j) < height)) {
                final offset =
                    z * sizeOfPlane + (y + j) * bps + (x + i) * bpp;
                rawData[offset] = col[0];
                rawData[offset + 1] = col[1];
                rawData[offset + 2] = col[2];
                rawData[offset + 3] = col[3];
              }
            }
          }
        }
      }
    }
    return rawData;
  }

  // ---- DXT5 ----

  static Uint8List _decodeDXT5(
      Uint8List inp, int width, int height, int depth) {
    const bpp = 4;
    final bps = width * bpp;
    final sizeOfPlane = bps * height;
    final rawData = Uint8List(depth * sizeOfPlane + height * bps + width * bpp);
    final data = ByteData.sublistView(inp);

    final colours = List.generate(4, (_) => [0, 0, 0, 0xFF]);
    final alphas = List<int>.filled(8, 0);
    var pos = 0;
    for (var z = 0; z < depth; z++) {
      for (var y = 0; y < height; y += 4) {
        for (var x = 0; x < width; x += 4) {
          if (pos + 16 > inp.length) return rawData;
          alphas[0] = inp[pos];
          alphas[1] = inp[pos + 1];
          final alphaMask = Uint8List.sublistView(inp, pos + 2, pos + 8);
          pos += 8;

          _dxtcReadColors(data, pos, colours);
          final bitmask = data.getUint32(pos + 4, Endian.little);
          pos += 8;

          for (var c = 0; c < 3; c++) {
            colours[2][c] = (2 * colours[0][c] + colours[1][c] + 1) ~/ 3;
            colours[3][c] = (colours[0][c] + 2 * colours[1][c] + 1) ~/ 3;
          }

          var k = 0;
          for (var j = 0; j < 4; j++) {
            for (var i = 0; i < 4; k++, i++) {
              final select = (bitmask & (0x03 << (k * 2))) >> (k * 2);
              final col = colours[select];
              if (((x + i) < width) && ((y + j) < height)) {
                final offset =
                    z * sizeOfPlane + (y + j) * bps + (x + i) * bpp;
                rawData[offset] = col[0];
                rawData[offset + 1] = col[1];
                rawData[offset + 2] = col[2];
              }
            }
          }

          if (alphas[0] > alphas[1]) {
            alphas[2] = (6 * alphas[0] + alphas[1] + 3) ~/ 7;
            alphas[3] = (5 * alphas[0] + 2 * alphas[1] + 3) ~/ 7;
            alphas[4] = (4 * alphas[0] + 3 * alphas[1] + 3) ~/ 7;
            alphas[5] = (3 * alphas[0] + 4 * alphas[1] + 3) ~/ 7;
            alphas[6] = (2 * alphas[0] + 5 * alphas[1] + 3) ~/ 7;
            alphas[7] = (alphas[0] + 6 * alphas[1] + 3) ~/ 7;
          } else {
            alphas[2] = (4 * alphas[0] + alphas[1] + 2) ~/ 5;
            alphas[3] = (3 * alphas[0] + 2 * alphas[1] + 2) ~/ 5;
            alphas[4] = (2 * alphas[0] + 3 * alphas[1] + 2) ~/ 5;
            alphas[5] = (alphas[0] + 4 * alphas[1] + 2) ~/ 5;
            alphas[6] = 0x00;
            alphas[7] = 0xFF;
          }

          var bits =
              alphaMask[0] | (alphaMask[1] << 8) | (alphaMask[2] << 16);
          for (var j = 0; j < 2; j++) {
            for (var i = 0; i < 4; i++) {
              if (((x + i) < width) && ((y + j) < height)) {
                final offset =
                    z * sizeOfPlane + (y + j) * bps + (x + i) * bpp + 3;
                rawData[offset] = alphas[bits & 0x07];
              }
              bits >>= 3;
            }
          }
          bits =
              alphaMask[3] | (alphaMask[4] << 8) | (alphaMask[5] << 16);
          for (var j = 2; j < 4; j++) {
            for (var i = 0; i < 4; i++) {
              if (((x + i) < width) && ((y + j) < height)) {
                final offset =
                    z * sizeOfPlane + (y + j) * bps + (x + i) * bpp + 3;
                rawData[offset] = alphas[bits & 0x07];
              }
              bits >>= 3;
            }
          }
        }
      }
    }
    return rawData;
  }

  static void _dxtcReadColors(ByteData data, int pos, List<List<int>> op) {
    var buf = (data.getUint8(pos + 1) & 0xF8) >> 3;
    op[0][0] = (buf << 3) | (buf >> 2);
    buf =
        ((data.getUint8(pos) & 0xE0) >> 5) | ((data.getUint8(pos + 1) & 0x7) << 3);
    op[0][1] = (buf << 2) | (buf >> 3);
    buf = data.getUint8(pos) & 0x1F;
    op[0][2] = (buf << 3) | (buf >> 2);

    buf = (data.getUint8(pos + 3) & 0xF8) >> 3;
    op[1][0] = (buf << 3) | (buf >> 2);
    buf =
        ((data.getUint8(pos + 2) & 0xE0) >> 5) | ((data.getUint8(pos + 3) & 0x7) << 3);
    op[1][1] = (buf << 2) | (buf >> 3);
    buf = data.getUint8(pos + 2) & 0x1F;
    op[1][2] = (buf << 3) | (buf >> 2);
  }

  static void _dxtcReadColor(int data, List<int> op) {
    var buf = (data & 0xF800) >> 11;
    op[0] = (buf << 3) | (buf >> 2);
    buf = (data & 0x7E0) >> 5;
    op[1] = (buf << 2) | (buf >> 3);
    buf = data & 0x1F;
    op[2] = (buf << 3) | (buf >> 2);
  }

  // ---- BC4 / BC5 ----

  static Uint8List _decodeBC4(Uint8List inp, int width, int height) {
    final ret = Uint8List(width * height * 4);
    var pos = 0;
    for (var yBlock = 0; yBlock < height ~/ 4; yBlock++) {
      for (var xBlock = 0; xBlock < width ~/ 4; xBlock++) {
        final rBytes = _decodeBC3Block(inp, pos);
        pos += 8;
        for (var i = 0; i < 16; i++) {
          final loc =
              _pixelLoc(width, xBlock * 4 + (i % 4), yBlock * 4 + (i ~/ 4), 4, 0);
          ret[loc] = rBytes[i];
          ret[loc + 1] = rBytes[i];
          ret[loc + 2] = rBytes[i];
          ret[loc + 3] = 0xFF;
        }
      }
    }
    return ret;
  }

  static Uint8List _decodeBC5(Uint8List inp, int width, int height) {
    final ret = Uint8List(width * height * 4);
    var pos = 0;
    for (var yBlock = 0; yBlock < height ~/ 4; yBlock++) {
      for (var xBlock = 0; xBlock < width ~/ 4; xBlock++) {
        final rBytes = _decodeBC3Block(inp, pos);
        pos += 8;
        final gBytes = _decodeBC3Block(inp, pos);
        pos += 8;
        for (var i = 0; i < 16; i++) {
          final x = xBlock * 4 + (i % 4);
          final y = yBlock * 4 + (i ~/ 4);
          ret[_pixelLoc(width, x, y, 4, 0)] = rBytes[i];
          ret[_pixelLoc(width, x, y, 4, 1)] = gBytes[i];
          ret[_pixelLoc(width, x, y, 4, 2)] = _getZNormal(rBytes[i], gBytes[i]);
          ret[_pixelLoc(width, x, y, 4, 3)] = 0xFF;
        }
      }
    }
    return ret;
  }

  static int _getZNormal(int x, int y) {
    final xf = (x / 127.5) - 1;
    final yf = (y / 127.5) - 1;
    var zval = 1 - xf * xf - yf * yf;
    final zv = sqrt(zval > 0 ? zval : 0);
    zval = zv < 1 ? zv : 1;
    return ((zval * 127) + 128).toInt();
  }

  static List<int> _decodeBC3Block(Uint8List inp, int pos) {
    final ref0 = inp[pos].toDouble();
    final ref1 = inp[pos + 1].toDouble();

    final refSl = List<double>.filled(8, 0);
    refSl[0] = ref0;
    refSl[1] = ref1;
    if (ref0 > ref1) {
      refSl[2] = (6 * ref0 + ref1) / 7;
      refSl[3] = (5 * ref0 + 2 * ref1) / 7;
      refSl[4] = (4 * ref0 + 3 * ref1) / 7;
      refSl[5] = (3 * ref0 + 4 * ref1) / 7;
      refSl[6] = (2 * ref0 + 5 * ref1) / 7;
      refSl[7] = (ref0 + 6 * ref1) / 7;
    } else {
      refSl[2] = (4 * ref0 + ref1) / 5;
      refSl[3] = (3 * ref0 + 2 * ref1) / 5;
      refSl[4] = (2 * ref0 + 3 * ref1) / 5;
      refSl[5] = (ref0 + 4 * ref1) / 5;
      refSl[6] = 0;
      refSl[7] = 255;
    }

    final indexBlock1 = _getBC3Indices(inp, pos + 2);
    final indexBlock2 = _getBC3Indices(inp, pos + 5);

    final bytes = List<int>.filled(16, 0);
    for (var i = 0; i < 8; i++) {
      bytes[7 - i] = refSl[indexBlock1[i]].toInt();
    }
    for (var i = 0; i < 8; i++) {
      bytes[15 - i] = refSl[indexBlock2[i]].toInt();
    }
    return bytes;
  }

  static List<int> _getBC3Indices(Uint8List buf, int pos) {
    final b0 = buf[pos];
    final b1 = buf[pos + 1];
    final b2 = buf[pos + 2];
    return [
      (b2 & 0xE0) >> 5,
      (b2 & 0x1C) >> 2,
      ((b2 & 0x03) << 1) | ((b1 & 0x80) >> 7),
      (b1 & 0x70) >> 4,
      (b1 & 0x0E) >> 1,
      ((b1 & 0x01) << 2) | ((b0 & 0xC0) >> 6),
      (b0 & 0x38) >> 3,
      b0 & 0x07,
    ];
  }
}
