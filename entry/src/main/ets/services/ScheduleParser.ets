import { OcrLine, ParseResult, ParsedCourse } from '../common/types';
import { DAY_KEYWORDS, MAX_SECTION } from '../common/constants';
import { FieldExtractor } from './FieldExtractor';
import { Logger } from '../common/Logger';

/** 星期表头命中记录 */
interface DayHit {
  day: number;
  x: number;
  y: number;
  w: number;
  h: number;
}

/** 节次标记行 */
interface SectionMark {
  start: number;
  end: number;
  y: number;
}

/** 网格行带 */
interface Band {
  topY: number;
  bottomY: number;
  startSection: number;
  endSection: number;
}

const TAG = 'ScheduleParser';

/**
 * OCR 课表解析器：把带坐标的识别文本行聚类为 "星期列 x 节次行带" 网格，
 * 再逐格抽取课程字段。表头无法定位或解析结果为空时，降级返回全文行。
 */
export class ScheduleParser {
  static parseOcr(lines: OcrLine[]): ParseResult {
    const sorted: OcrLine[] = lines.slice().sort((a: OcrLine, b: OcrLine) => a.y - b.y || a.x - b.x);
    const rawLines: string[] = [];
    for (const l of sorted) {
      const t = l.text.trim();
      if (t.length > 0) {
        rawLines.push(t);
      }
    }

    // 1. 星期表头命中
    const hits: DayHit[] = [];
    for (const l of sorted) {
      const d = ScheduleParser.matchDayText(l.text);
      if (d > 0) {
        const hit: DayHit = { day: d, x: l.x, y: l.y, w: l.w, h: l.h };
        hits.push(hit);
      }
    }
    if (hits.length < 2) {
      return ScheduleParser.fallback(rawLines);
    }

    // 2. 按 y 聚簇，选包含最多不同星期的簇作为表头行
    const used: boolean[] = [];
    for (let i = 0; i < hits.length; i++) {
      used.push(false);
    }
    let best: DayHit[] = [];
    for (let i = 0; i < hits.length; i++) {
      if (used[i]) {
        continue;
      }
      used[i] = true;
      const cluster: DayHit[] = [hits[i]];
      const tol = Math.max(14, hits[i].h * 1.2);
      for (let j = i + 1; j < hits.length; j++) {
        if (!used[j] && Math.abs(hits[j].y - hits[i].y) <= tol) {
          cluster.push(hits[j]);
          used[j] = true;
        }
      }
      if (ScheduleParser.distinctDays(cluster) > ScheduleParser.distinctDays(best)) {
        best = cluster;
      }
    }
    if (ScheduleParser.distinctDays(best) < 2) {
      return ScheduleParser.fallback(rawLines);
    }

    // 3. 每天取最靠左命中，推列边界
    best.sort((a: DayHit, b: DayHit) => a.x - b.x);
    const byDay: (DayHit | undefined)[] = [];
    for (const h of best) {
      if (byDay[h.day - 1] === undefined) {
        byDay[h.day - 1] = h;
      }
    }
    const cols: DayHit[] = [];
    for (const h of byDay) {
      if (h !== undefined) {
        cols.push(h);
      }
    }
    if (cols.length < 2) {
      return ScheduleParser.fallback(rawLines);
    }
    const bounds: number[] = [];
    bounds.push(cols[0].x - Math.max(24, cols[0].w * 0.6));
    for (let i = 1; i < cols.length; i++) {
      bounds.push((cols[i - 1].x + cols[i].x) / 2);
    }
    const lastCol = cols[cols.length - 1];
    bounds.push(lastCol.x + lastCol.w + Math.max(24, lastCol.w * 0.6));

    let headerY = cols[0].y;
    for (const c of cols) {
      if (c.y < headerY) {
        headerY = c.y;
      }
    }
    const headerH = Math.max(10, cols[0].h);

    // 4. 节次行带：位于第一列左边界之外的节次标记行
    const marks: SectionMark[] = [];
    for (const l of sorted) {
      if (l.y <= headerY + headerH) {
        continue;
      }
      if (l.x >= bounds[0]) {
        continue;
      }
      const sec = FieldExtractor.parseSectionLabel(l.text);
      if (sec !== null) {
        const m: SectionMark = { start: sec.start, end: sec.end, y: l.y };
        marks.push(m);
      }
    }
    marks.sort((a: SectionMark, b: SectionMark) => a.y - b.y);

    const bands: Band[] = [];
    if (marks.length > 0) {
      for (let i = 0; i < marks.length; i++) {
        const topY = i === 0 ? headerY + headerH + 1 : (marks[i - 1].y + marks[i].y) / 2;
        const bottomY = i === marks.length - 1 ? Number.MAX_VALUE : (marks[i].y + marks[i + 1].y) / 2;
        const b: Band = {
          topY: topY,
          bottomY: bottomY,
          startSection: marks[i].start,
          endSection: marks[i].end
        };
        bands.push(b);
      }
    } else {
      // 无节次标记：按内容行平均行高均分行带
      let sumH = 0;
      let count = 0;
      let minY = Number.MAX_VALUE;
      let maxBottom = 0;
      for (const l of sorted) {
        if (l.y > headerY + headerH && l.x >= bounds[0]) {
          sumH += l.h;
          count++;
          if (l.y < minY) {
            minY = l.y;
          }
          if (l.y + l.h > maxBottom) {
            maxBottom = l.y + l.h;
          }
        }
      }
      if (count === 0) {
        return ScheduleParser.fallback(rawLines);
      }
      const bandH = Math.max(40, (sumH / count) * 2.2);
      const bandCount = Math.max(1, Math.ceil((maxBottom - minY + bandH * 0.4) / bandH));
      for (let i = 0; i < bandCount; i++) {
        const b: Band = {
          topY: i === 0 ? headerY + headerH + 1 : minY + i * bandH - bandH * 0.35,
          bottomY: minY + (i + 1) * bandH - bandH * 0.35,
          startSection: i + 1,
          endSection: i + 1
        };
        bands.push(b);
      }
    }

    // 5. 归并单元格
    const cellMap: Map<string, string> = new Map();
    for (const l of sorted) {
      if (l.y <= headerY + headerH) {
        continue;
      }
      if (l.x < bounds[0]) {
        continue;
      }
      let col = -1;
      for (let i = 0; i < cols.length; i++) {
        if (l.x >= bounds[i] && l.x < bounds[i + 1]) {
          col = i;
          break;
        }
      }
      if (col < 0) {
        continue;
      }
      let row = -1;
      for (let i = 0; i < bands.length; i++) {
        if (l.y >= bands[i].topY && l.y < bands[i].bottomY) {
          row = i;
          break;
        }
      }
      if (row < 0) {
        continue;
      }
      const key = row.toString() + '_' + col.toString();
      const prev = cellMap.get(key);
      if (prev === undefined) {
        cellMap.set(key, l.text.trim());
      } else {
        cellMap.set(key, prev + '\n' + l.text.trim());
      }
    }

    // 6. 逐格抽取课程
    const courses: ParsedCourse[] = [];
    cellMap.forEach((text: string, key: string) => {
      const parts = key.split('_');
      const band = bands[parseInt(parts[0], 10)];
      const day = cols[parseInt(parts[1], 10)].day;
      const parsed = FieldExtractor.extractCourse(text);
      if (parsed === undefined) {
        return;
      }
      parsed.dayOfWeek = day;
      if (!parsed.hasSection) {
        parsed.startSection = Math.max(1, Math.min(MAX_SECTION, band.startSection));
        parsed.endSection = Math.max(parsed.startSection,
          Math.min(MAX_SECTION, band.endSection));
      }
      courses.push(parsed);
    });

    Logger.info(TAG, 'OCR grid parsed courses: ' + courses.length.toString());
    const ok: ParseResult = { courses: courses, rawLines: rawLines, gridFound: courses.length > 0 };
    return ok;
  }

  private static fallback(rawLines: string[]): ParseResult {
    Logger.info(TAG, 'OCR grid not found, fallback to raw lines');
    const r: ParseResult = { courses: [], rawLines: rawLines, gridFound: false };
    return r;
  }

  private static distinctDays(cluster: DayHit[]): number {
    const days: number[] = [];
    for (const h of cluster) {
      if (!days.includes(h.day)) {
        days.push(h.day);
      }
    }
    return days.length;
  }

  /** 短文本是否以星期关键词开头，返回 1~7 或 -1 */
  private static matchDayText(text: string): number {
    const s = text.trim().toLowerCase();
    if (s.length === 0 || s.length > 12) {
      return -1;
    }
    for (let d = 0; d < DAY_KEYWORDS.length; d++) {
      for (const kw of DAY_KEYWORDS[d]) {
        if (s.startsWith(kw)) {
          return d + 1;
        }
      }
    }
    return -1;
  }
}
