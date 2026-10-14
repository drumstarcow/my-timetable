import { ParseResult, ParsedCourse } from '../common/types';
import { MAX_SECTION } from '../common/constants';
import { FieldExtractor } from './FieldExtractor';
import { Logger } from '../common/Logger';

/**
 * 矩阵（二维表格）解析器：CSV / Excel 解析出的 string[][] -> 课表。
 * 与 OCR 解析共用字段抽取逻辑，行列定位比 OCR 更直接。
 */
export class MatrixParser {
  static parseMatrix(matrix: string[][]): ParseResult {
    // 原文行（降级展示用）
    const rawLines: string[] = [];
    for (const row of matrix) {
      const joined = MatrixParser.joinRow(row);
      if (joined.length > 0) {
        rawLines.push(joined);
      }
    }

    // 1. 定位表头行与各天列
    const dayCol: number[] = [-1, -1, -1, -1, -1, -1, -1];
    let headerRow = -1;
    const searchLimit = Math.min(matrix.length, 10);
    for (let r = 0; r < searchLimit; r++) {
      for (let i = 0; i < 7; i++) {
        dayCol[i] = -1;
      }
      let hits = 0;
      const row = matrix[r];
      for (let c = 0; c < row.length; c++) {
        const d = MatrixParser.matchDayCell(row[c]);
        if (d > 0 && dayCol[d - 1] < 0) {
          dayCol[d - 1] = c;
          hits++;
        }
      }
      if (hits >= 2) {
        headerRow = r;
        break;
      }
    }

    // 2. 无表头时的兜底：假定第 1 行为表头、节次列在最左
    if (headerRow < 0) {
      let width = 0;
      for (const row of matrix) {
        if (row.length > width) {
          width = row.length;
        }
      }
      const offset = width >= 8 ? 1 : 0;
      for (let i = 0; i < 7; i++) {
        dayCol[i] = offset + i;
      }
      headerRow = 0;
      Logger.info('MatrixParser', 'no header row found, fallback with offset ' + offset.toString());
    }

    // 3. 节次列：表头中非星期列且含"节/时间/午"关键字
    let sectionCol = -1;
    const headerCells = matrix[headerRow];
    for (let c = 0; c < headerCells.length; c++) {
      if (dayCol.includes(c)) {
        continue;
      }
      const h = headerCells[c];
      if (h.includes('节') || h.includes('时间') || h.includes('午')) {
        sectionCol = c;
        break;
      }
    }

    // 4. 数据行 -> 课程
    const courses: ParsedCourse[] = [];
    for (let r = headerRow + 1; r < matrix.length; r++) {
      const row = matrix[r];
      let rowSection = 0;
      if (sectionCol >= 0 && sectionCol < row.length) {
        const sec = FieldExtractor.parseSectionLabel(row[sectionCol]);
        if (sec !== null) {
          rowSection = sec.start;
        }
      }
      for (let d = 0; d < 7; d++) {
        const col = dayCol[d];
        if (col < 0 || col >= row.length) {
          continue;
        }
        const cellText = row[col].trim();
        if (cellText.length === 0) {
          continue;
        }
        const parsed = FieldExtractor.extractCourse(cellText);
        if (parsed === undefined) {
          continue;
        }
        parsed.dayOfWeek = d + 1;
        if (!parsed.hasSection && rowSection > 0 && rowSection <= MAX_SECTION) {
          parsed.startSection = rowSection;
          parsed.endSection = rowSection;
        }
        courses.push(parsed);
      }
    }

    // 5. 合并相邻同课（Excel 每节一行时会产生重复行）
    const merged = MatrixParser.mergeAdjacent(courses);
    Logger.info('MatrixParser', 'matrix parsed courses: ' + merged.length.toString());
    const result: ParseResult = { courses: merged, rawLines: rawLines, gridFound: merged.length > 0 };
    return result;
  }

  private static joinRow(row: string[]): string {
    const cells: string[] = [];
    for (const c of row) {
      if (c.trim().length > 0) {
        cells.push(c.trim());
      }
    }
    return cells.join(' | ');
  }

  /** 表头单元格 -> 星期几（1~7），要求短文本 */
  private static matchDayCell(cell: string): number {
    const s = cell.trim().toLowerCase();
    if (s.length === 0 || s.length > 12) {
      return -1;
    }
    if (s.includes('日期') || s.includes('时间')) {
      return -1;
    }
    const keywords: string[][] = [
      ['周一', '星期一', '礼拜一', 'mon', 'monday'],
      ['周二', '星期二', '礼拜二', 'tue', 'tues', 'tuesday'],
      ['周三', '星期三', '礼拜三', 'wed', 'weds', 'wednesday'],
      ['周四', '星期四', '礼拜四', 'thu', 'thur', 'thurs', 'thursday'],
      ['周五', '星期五', '礼拜五', 'fri', 'friday'],
      ['周六', '星期六', '礼拜六', 'sat', 'saturday'],
      ['周日', '星期日', '礼拜天', '礼拜日', 'sun', 'sunday']
    ];
    for (let d = 0; d < keywords.length; d++) {
      for (const kw of keywords[d]) {
        if (s.startsWith(kw)) {
          return d + 1;
        }
      }
    }
    return -1;
  }

  /** 相邻节次、同课程同教师的合并为一段（连堂课） */
  private static mergeAdjacent(list: ParsedCourse[]): ParsedCourse[] {
    const sorted = list.slice().sort((a: ParsedCourse, b: ParsedCourse) => {
      if (a.dayOfWeek !== b.dayOfWeek) {
        return a.dayOfWeek - b.dayOfWeek;
      }
      return a.startSection - b.startSection;
    });
    const out: ParsedCourse[] = [];
    for (const cur of sorted) {
      const prev = out.length > 0 ? out[out.length - 1] : undefined;
      if (prev !== undefined
        && prev.dayOfWeek === cur.dayOfWeek
        && prev.name === cur.name
        && prev.teacher === cur.teacher
        && prev.room === cur.room
        && prev.weekType === cur.weekType
        && prev.startWeek === cur.startWeek
        && prev.endWeek === cur.endWeek
        && cur.startSection === prev.endSection + 1) {
        prev.endSection = cur.endSection;
        continue;
      }
      out.push(cur);
    }
    return out;
  }
}
