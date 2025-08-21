// Official FastLZ implementation from Solady.js
// Source: https://raw.githubusercontent.com/Vectorized/solady/refs/heads/main/js/solady.js

function byteToString(b: number): string {
  return (b | 0x100).toString(16).slice(1);
}

function parseByte(data: string, i: number): number {
  return parseInt(data.substr(i, 2), 16);
}

function hexToBytes(data: string): number[] {
  const a: number[] = [];
  for (let i = 0; i < data.length; i += 2) {
    a.push(parseByte(data, i));
  }
  return a;
}

function uint8ArrayToHex(data: Uint8Array): string {
  let hex = "";
  for (let i = 0; i < data.length; i++) {
    hex += byteToString(data[i]);
  }
  return hex;
}

/**
 * Compresses data with the FastLZ LZ77 algorithm.
 * Compatible with Solady's LibZip.flzDecompress
 * @param data The original data as Uint8Array
 * @returns The compressed result as Uint8Array
 */
function flzCompress(data: Uint8Array): Uint8Array {
  // Convert to hex string format expected by Solady implementation
  const hexData = "0x" + uint8ArrayToHex(data);
  
  // Use the official Solady FastLZ compress function
  const ib = hexToBytes(hexData.slice(2));
  const b = ib.length - 4;
  const ht: number[] = [];
  const ob: number[] = [];
  let a = 0, i = 2, o = 0, j: number, s: number, h: number, d: number, c: number, l: number, r: number, p: number, q: number, e: number;

  function u24(i: number): number {
    return ib[i] | (ib[++i] << 8) | (ib[++i] << 16);
  }

  function hash(x: number): number {
    return ((2654435769 * x) >> 19) & 8191;
  }

  function literals(r: number, s: number): void {
    while (r >= 32) {
      ob[o++] = 31;
      for (j = 32; j--; r--) ob[o++] = ib[s++];
    }
    if (r) {
      ob[o++] = r - 1;
      for (; r--; ) ob[o++] = ib[s++];
    }
  }

  while (i < b - 9) {
    do {
      r = ht[h = hash(s = u24(i))] || 0;
      c = (d = (ht[h] = i) - r) < 8192 ? u24(r) : 0x1000000;
    } while (i < b - 9 && i++ && s != c);
    
    if (i >= b - 9) break;
    
    if (--i > a) literals(i - a, a);
    
    for (l = 0, p = r + 3, q = i + 3, e = b - q; l < e; l++) {
      e *= ib[p + l] === ib[q + l] ? 1 : 0;
    }
    
    i += l;
    
    for (--d; l > 262; l -= 262) {
      ob[o++] = 224 + (d >> 8);
      ob[o++] = 253;
      ob[o++] = d & 255;
    }
    
    if (l < 7) {
      ob[o++] = (l << 5) + (d >> 8);
      ob[o++] = d & 255;
    } else {
      ob[o++] = 224 + (d >> 8);
      ob[o++] = l - 7;
      ob[o++] = d & 255;
    }
    
    ht[hash(u24(i))] = i++;
    ht[hash(u24(i))] = i++;
    a = i;
  }
  
  literals(b + 4 - a, a);
  
  return new Uint8Array(ob);
}

const fastlz = {
  compress: flzCompress,
};

export default fastlz;