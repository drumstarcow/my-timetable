import zlib from '@ohos.zlib';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Logger } from '../common/Logger';

const TAG = 'ExcelParser';

/** 列字母（A/B/…/AA）转 1 起始列号 */
function colLettersToNumber(letters: string): number {
  let n = 0;
  for (let i = 0; i < letters.length; i++) {
    const code = letters.charCodeAt(i);
    if (code >= 65 && code <= 90) {
      n = n * 26 + (code - 64);
    } else if (code >= 97 && code <= 122) {
      n = n * 26 + (code - 96);
    } else {
      break;
    }
  }
  return Math.max(1, n);
}

/** 解码 XML 实体 */
function decodeXmlEntities(s: string): string {
  let r = s.replace(/&#x([0-9a-fA-F]+);/g, (m: string, hex: string) => {
    const code = parseInt(hex, 16);
    return code > 0 ? String.fromCharCode(code) : m;
  });
  r = r.replace(/&#(\d+);/g, (m: string, dec: string) => {
    const code = parseInt(dec, 10);
    return code > 0 ? String.fromCharCode(code) : m;
  });
  r = r.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"');
  r = r.replace(/&apos;/g, '\'').replace(/&nbsp;/g, ' ');
  r = r.replace(/&amp;/g, '&');
  return r;
}

/**
 * xlsx 解析器（零三方依赖）：
 * xlsx 本质是 ZIP 包，用系统 zlib 解压后按正则解析
 * sharedStrings.xml 与首个工作表 XML，得到 string[][]。
 */
export class ExcelParser {
  /** xlsx 字节流 -> 二维字符串数组（取第一个工作表） */
  static async parseToMatrix(arrayBuffer: ArrayBuffer, cacheDir: string): Promise<string[][]> {
    const stamp = Date.now().toString();
    const zipPath = cacheDir + '/import_' + stamp + '.xlsx';
    const destDir = cacheDir + '/xlsx_' + stamp;
    try {
      const file = await fs.open(zipPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      try {
        await fs.write(file.fd, arrayBuffer);
      } finally {
        await fs.close(file.fd);
      }
      await zlib.decompressFile(zipPath, destDir);

      const shared = await ExcelParser.readSharedStrings(destDir);
      const sheetRelPath = await ExcelParser.resolveFirstSheetPath(destDir);
      const sheetXml = await ExcelParser.readFileText(destDir + '/' + sheetRelPath);
      return ExcelParser.parseSheetXml(sheetXml, shared);
    } finally {
      await ExcelParser.cleanup(zipPath, destDir);
    }
  }

  private static async readFileText(path: string): Promise<string> {
    const file = await fs.open(path, fs.OpenMode.READ_ONLY);
    try {
      const stat = await fs.stat(file.fd);
      const buf = new ArrayBuffer(stat.size);
      await fs.read(file.fd, buf);
      return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
    } finally {
      await fs.close(file.fd);
    }
  }

  private static async readSharedStrings(destDir: string): Promise<string[]> {
    const out: string[] = [];
    try {
      const text = await ExcelParser.readFileText(destDir + '/xl/sharedStrings.xml');
      const blocks = text.match(/<si>[\s\S]*?<\/si>/g);
      if (blocks !== null) {
        for (const block of blocks) {
          let s = '';
          const ts = block.match(/<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g);
          if (ts !== null) {
            for (const t of ts) {
              s += t.replace(/<\/?t(?:\s[^>]*)?>/g, '');
            }
          }
          out.push(decodeXmlEntities(s));
        }
      }
    } catch (e) {
      // 没有 sharedStrings.xml（全部内联字符串）时忽略
      Logger.info(TAG, 'no sharedStrings.xml, use inline strings');
    }
    return out;
  }

  /** 通过 workbook.xml 与 rels 定位第一个工作表，失败回退 sheet1.xml */
  private static async resolveFirstSheetPath(destDir: string): Promise<string> {
    try {
      const wbXml = await ExcelParser.readFileText(destDir + '/xl/workbook.xml');
      const m = wbXml.match(/<sheet[^>]*r:id="([^"]+)"/);
      const rid = m !== null ? m[1] : '';
      if (rid.length > 0) {
        const relsXml = await ExcelParser.readFileText(destDir + '/xl/_rels/workbook.xml.rels');
        const rels = relsXml.match(/<Relationship[^>]*>/g);
        if (rels !== null) {
          for (const rel of rels) {
            const idM = rel.match(/Id="([^"]+)"/);
            const tgM = rel.match(/Target="([^"]+)"/);
            if (idM !== null && tgM !== null && idM[1] === rid) {
              const target = tgM[1];
              if (target.startsWith('/xl/')) {
                return target.substring(1);
              }
              if (target.startsWith('/')) {
                return target.substring(1);
              }
              return 'xl/' + target;
            }
          }
        }
      }
    } catch (e) {
      Logger.warn(TAG, 'resolve sheet path failed, fallback to sheet1.xml');
    }
    return 'xl/worksheets/sheet1.xml';
  }

  /** 工作表 XML -> string[][] */
  private static parseSheetXml(sheetXml: string, shared: string[]): string[][] {
    const rowMap: Map<number, Map<number, string>> = new Map();
    const cellRe = /<c\s([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g;

    let m: RegExpExecArray | null = cellRe.exec(sheetXml);
    while (m !== null) {
      const attrs = m[1];
      const body = m.length > 2 && m[2] !== undefined ? m[2] : '';
      const rM = attrs.match(/r="([A-Za-z]+)(\d+)"/);
      if (rM !== null) {
        const colIdx = colLettersToNumber(rM[1]);
        const rowIdx = parseInt(rM[2], 10);
        if (!Number.isNaN(rowIdx) && rowIdx > 0) {
          const value = ExcelParser.cellValue(attrs, body, shared);
          let cols = rowMap.get(rowIdx);
          if (cols === undefined) {
            cols = new Map<number, string>();
            rowMap.set(rowIdx, cols);
          }
          cols.set(colIdx, value);
        }
      }
      m = cellRe.exec(sheetXml);
    }

    // 行号排序 + 最大列数
    const rowNums: number[] = [];
    let maxCol = 1;
    rowMap.forEach((cols: Map<number, string>, key: number) => {
      rowNums.push(key);
      cols.forEach((_v: string, k: number) => {
        if (k > maxCol) {
          maxCol = k;
        }
      });
    });
    rowNums.sort((a: number, b: number) => a - b);

    const matrix: string[][] = [];
    for (const r of rowNums) {
      const rowArr: string[] = [];
      for (let c = 1; c <= maxCol; c++) {
        const cols = rowMap.get(r);
        const v = cols !== undefined ? cols.get(c) : undefined;
        rowArr.push(v !== undefined ? v : '');
      }
      matrix.push(rowArr);
    }
    return matrix;
  }

  /** 单元格取值：t="s" 共享字符串 / t="inlineStr" 内联 / 其余按文本 */
  private static cellValue(attrs: string, body: string, shared: string[]): string {
    const tM = attrs.match(/t="([a-z]+)"/);
    const cellType = tM !== null ? tM[1] : '';
    if (cellType === 'inlineStr') {
      let s = '';
      const ts = body.match(/<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g);
      if (ts !== null) {
        for (const t of ts) {
          s += t.replace(/<\/?t(?:\s[^>]*)?>/g, '');
        }
      }
      return decodeXmlEntities(s);
    }
    const vM = body.match(/<v>([\s\S]*?)<\/v>/);
    if (vM === null) {
      return '';
    }
    if (cellType === 's') {
      const idx = parseInt(vM[1], 10);
      return idx >= 0 && idx < shared.length ? shared[idx] : '';
    }
    return decodeXmlEntities(vM[1]);
  }

  /** 清理临时文件与目录（尽力而为） */
  private static async cleanup(zipPath: string, destDir: string): Promise<void> {
    try {
      await fs.unlink(zipPath);
    } catch (e) {
      // 忽略清理失败
    }
    try {
      await ExcelParser.removeDirRecursive(destDir);
    } catch (e) {
      // 忽略清理失败
    }
  }

  private static async removeDirRecursive(dir: string): Promise<void> {
    const names = await fs.listFile(dir);
    for (const n of names) {
      const child = dir + '/' + n;
      const stat = await fs.stat(child);
      if (stat.isDirectory()) {
        await ExcelParser.removeDirRecursive(child);
      } else {
        await fs.unlink(child);
      }
    }
    await fs.rmdir(dir);
  }
}
