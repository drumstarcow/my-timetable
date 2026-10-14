import { util } from '@kit.ArkTS';

/** CSV 解析器：UTF-8 解码 + 引号感知的文本解析 */
export class CsvParser {
  /** ArrayBuffer 转 UTF-8 文本 */
  static decodeUtf8(arrayBuffer: ArrayBuffer): string {
    const decoder = util.TextDecoder.create('utf-8');
    return decoder.decodeToString(new Uint8Array(arrayBuffer));
  }

  /** 检测是否 GBK 文件被误按 UTF-8 解码（出现大量替换符 U+FFFD） */
  static looksLikeGarbled(text: string): boolean {
    let bad = 0;
    for (let i = 0; i < text.length; i++) {
      if (text.charCodeAt(i) === 0xFFFD) {
        bad++;
      }
    }
    return bad > Math.max(3, text.length * 0.02);
  }

  /**
   * CSV 文本 -> 二维数组。
   * 支持双引号包裹的字段（可含逗号/换行）与转义引号 ""。
   */
  static parse(text: string): string[][] {
    const rows: string[][] = [];
    let row: string[] = [];
    let field = '';
    let inQuotes = false;
    let i = 0;
    while (i < text.length) {
      const ch = text.charAt(i);
      if (inQuotes) {
        if (ch === '"') {
          if (i + 1 < text.length && text.charAt(i + 1) === '"') {
            field += '"';
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field += ch;
        }
      } else {
        if (ch === '"') {
          inQuotes = true;
        } else if (ch === ',') {
          row.push(field);
          field = '';
        } else if (ch === '\n') {
          row.push(field);
          field = '';
          rows.push(row);
          row = [];
        } else if (ch !== '\r') {
          field += ch;
        }
      }
      i++;
    }
    // 收尾：最后一个字段/行
    if (field.length > 0 || row.length > 0) {
      row.push(field);
      rows.push(row);
    }
    return rows;
  }
}
