import { ParsedCourse } from '../common/types';
import { MAX_SECTION, MAX_WEEK, colorIndexForName } from '../common/constants';

/** 节次范围 */
export interface SectionRange {
  start: number;
  end: number;
}

/**
 * 字段抽取器：从单元格/单行文本中抽取课程字段。
 * OCR 网格解析与 CSV/Excel 矩阵解析共用。
 */
export class FieldExtractor {
  /** 解析节次标签（"1"、"第3节"、"1-2节"、"第十一节"）；不是节次标签返回 null */
  static parseSectionLabel(text: string): SectionRange | null {
    const s = text.replace(/\s+/g, '');
    if (s.length === 0 || s.length > 16) {
      return null;
    }
    const m = s.match(/^第?([0-9一二三四五六七八九十]+)(?:[-~－—至]第?([0-9一二三四五六七八九十]+))?节?$/);
    if (m === null) {
      return null;
    }
    const start = FieldExtractor.cnOrNum(m[1]);
    const end = m[2] !== undefined ? FieldExtractor.cnOrNum(m[2]) : start;
    if (start < 1 || end < start || end > MAX_SECTION) {
      return null;
    }
    const r: SectionRange = { start: start, end: end };
    return r;
  }

  /** 中文数字或阿拉伯数字 -> number，失败返回 -1 */
  static cnOrNum(s: string): number {
    if (/^[0-9]+$/.test(s)) {
      return parseInt(s, 10);
    }
    const digits = '零一二三四五六七八九';
    if (s === '十') {
      return 10;
    }
    if (s.startsWith('十')) {
      const rest = digits.indexOf(s.charAt(1));
      return rest > 0 ? 10 + rest : 10;
    }
    if (s.endsWith('十')) {
      const head = digits.indexOf(s.charAt(0));
      return head > 0 ? head * 10 : 10;
    }
    const tenPos = s.indexOf('十');
    if (tenPos > 0) {
      const head = digits.indexOf(s.charAt(0));
      const rest = digits.indexOf(s.charAt(tenPos + 1));
      if (head > 0 && rest > 0) {
        return head * 10 + rest;
      }
    }
    const single = digits.indexOf(s);
    return single > 0 ? single : -1;
  }

  /**
   * 单元格文本 -> 课程。
   * 抽取优先级：周次 > 单双周 > 节次 > 教师 > 教室 > 课程名（剩余最长行）。
   */
  static extractCourse(cellText: string): ParsedCourse | undefined {
    const rawLines = cellText.split('\n');
    const trimmed: string[] = [];
    for (const l of rawLines) {
      const t = l.trim();
      if (t.length > 0) {
        trimmed.push(t);
      }
    }
    if (trimmed.length === 0) {
      return undefined;
    }

    const parsed: ParsedCourse = {
      id: undefined,
      name: '',
      teacher: '',
      room: '',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 1,
      weekType: 0,
      startWeek: 1,
      endWeek: MAX_WEEK,
      colorIndex: 0,
      priority: 0,
      content: '',
      rawText: cellText,
      hasSection: false
    };
    const leftovers: string[] = [];

    for (const line of trimmed) {
      const clean = line.replace(/\s+/g, ' ').trim();
      if (clean.length === 0) {
        continue;
      }
      // 周次范围，如 "1-16周"
      const wm = clean.match(/(\d{1,2})\s*[-~－—至]\s*(\d{1,2})\s*周/);
      if (wm !== null) {
        const sw = parseInt(wm[1], 10);
        const ew = parseInt(wm[2], 10);
        parsed.startWeek = Math.max(1, Math.min(MAX_WEEK, sw));
        parsed.endWeek = Math.max(parsed.startWeek, Math.min(MAX_WEEK, ew));
        if (clean.includes('单周')) {
          parsed.weekType = 1;
        } else if (clean.includes('双周')) {
          parsed.weekType = 2;
        }
        continue;
      }
      // 单独的单双周
      if (clean.includes('单周') || clean.includes('双周')) {
        parsed.weekType = clean.includes('单周') ? 1 : 2;
        continue;
      }
      // 显式节次范围，如 "第3-4节"
      const sm = clean.match(/第?\s*(\d{1,2})\s*[-~－—至]\s*(\d{1,2})\s*节/);
      if (sm !== null) {
        let s1 = FieldExtractor.clampSection(parseInt(sm[1], 10));
        let s2 = FieldExtractor.clampSection(parseInt(sm[2], 10));
        if (s2 < s1) {
          const tmp = s1;
          s1 = s2;
          s2 = tmp;
        }
        parsed.startSection = s1;
        parsed.endSection = s2;
        parsed.hasSection = true;
        continue;
      }
      // 单节，如 "第5节"
      const sm1 = clean.match(/^第\s*(\d{1,2})\s*节$/);
      if (sm1 !== null) {
        parsed.startSection = FieldExtractor.clampSection(parseInt(sm1[1], 10));
        parsed.endSection = parsed.startSection;
        parsed.hasSection = true;
        continue;
      }
      // 教师
      if (clean.startsWith('@') || /老师|教师|教授|讲师|副教授/.test(clean)) {
        if (parsed.teacher.length === 0) {
          parsed.teacher = FieldExtractor.cleanLine(clean);
        }
        continue;
      }
      // 教室
      if (FieldExtractor.looksLikeRoom(clean)) {
        if (parsed.room.length === 0) {
          parsed.room = FieldExtractor.cleanLine(clean);
        }
        continue;
      }
      leftovers.push(clean);
    }

    // 课程名 = 剩余行中最长的一行，兜底取第一行
    let name = '';
    for (const l of leftovers) {
      if (l.length > name.length) {
        name = l;
      }
    }
    if (name.length === 0) {
      name = FieldExtractor.cleanLine(trimmed[0]);
    }
    if (name.length === 0) {
      return undefined;
    }
    parsed.name = name;
    parsed.colorIndex = colorIndexForName(parsed.name);
    if (parsed.endSection < parsed.startSection) {
      parsed.endSection = parsed.startSection;
    }
    parsed.startWeek = Math.max(1, parsed.startWeek);
    parsed.endWeek = Math.min(MAX_WEEK, Math.max(parsed.endWeek, parsed.startWeek));
    return parsed;
  }

  private static clampSection(v: number): number {
    if (Number.isNaN(v)) {
      return 1;
    }
    return Math.max(1, Math.min(MAX_SECTION, v));
  }

  /** 去掉周次/节次/符号等杂质，保留干净的人名或地点 */
  private static cleanLine(s: string): string {
    let r = s;
    r = r.replace(/\d{1,2}\s*[-~－—至]\s*\d{1,2}\s*周/g, '');
    r = r.replace(/单周|双周/g, '');
    r = r.replace(/第?\s*\d{1,2}\s*[-~－—至]?\s*\d{1,2}\s*节/g, '');
    r = r.replace(/[@:：]/g, ' ');
    r = r.replace(/\s+/g, ' ').trim();
    return r;
  }

  /** 判断文本是否像教室/地点 */
  private static looksLikeRoom(s: string): boolean {
    if (s.length > 20 || !/\d/.test(s)) {
      return false;
    }
    if (/(楼|室|馆|区|栋|厅|机房|实验室|教室)/.test(s)) {
      return true;
    }
    // "教1-201"、"A3-301"、"3-201"
    if (/^[A-Za-z\d]{1,4}\s*[-－]\s*\d{3,4}$/.test(s)) {
      return true;
    }
    if (/^\d{3,4}$/.test(s)) {
      return true;
    }
    if (/周/.test(s)) {
      return false;
    }
    return /(教[一二三四五六七八九十\d]{1,3}|[A-Z]\d{1,3})/.test(s);
  }
}
