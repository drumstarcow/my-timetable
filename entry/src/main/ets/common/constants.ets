import { SectionTime } from './types';

/** 学期最大周数 */
export const MAX_WEEK: number = 25;
/** 最大节次数 */
export const MAX_SECTION: number = 15;
/** 默认节次数 */
export const DEFAULT_SECTION_COUNT: number = 12;
/** 周网格行高（vp） */
export const GRID_ROW_HEIGHT: number = 68;
/** 周网格表头行高（vp） */
export const GRID_HEADER_HEIGHT: number = 48;
/** 节次时间列宽（vp） */
export const GRID_SECTION_COL_WIDTH: number = 92;

/** 星期名称，索引 0 对应周一 */
export const WEEK_DAY_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
/** 周类型名称：0=每周 1=单周 2=双周 */
export const WEEK_TYPE_NAMES: string[] = ['每周', '单周', '双周'];

/** 星期关键词（用于表头/网格识别），索引 0 对应周一 */
export const DAY_KEYWORDS: string[][] = [
  ['周一', '星期一', '礼拜一', 'mon', 'monday'],
  ['周二', '星期二', '礼拜二', 'tue', 'tues', 'tuesday'],
  ['周三', '星期三', '礼拜三', 'wed', 'weds', 'wednesday'],
  ['周四', '星期四', '礼拜四', 'thu', 'thur', 'thurs', 'thursday'],
  ['周五', '星期五', '礼拜五', 'fri', 'friday'],
  ['周六', '星期六', '礼拜六', 'sat', 'saturday'],
  ['周日', '星期日', '礼拜天', '礼拜日', 'sun', 'sunday']
];

/** 课程卡片配色（colorIndex 取模使用） */
export const CARD_COLORS: string[] = [
  '#4C7DD9', '#5BA054', '#C9772E', '#8A5BC4',
  '#C25450', '#2E9BA6', '#7A8B3A', '#4A9C7E'
];

function pad2(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

function minutesToTime(totalMinutes: number): string {
  const m = Math.max(0, Math.min(23 * 60 + 59, totalMinutes));
  return pad2(Math.floor(m / 60)) + ':' + pad2(m % 60);
}

/** 生成默认节次时间：从 08:00 起，每节 45 分钟、节间休息 10 分钟 */
export function defaultSectionTimes(count: number): SectionTime[] {
  const times: SectionTime[] = [];
  let cursor = 8 * 60;
  for (let i = 0; i < count; i++) {
    const st: SectionTime = {
      start: minutesToTime(cursor),
      end: minutesToTime(cursor + 45)
    };
    times.push(st);
    cursor += 55;
  }
  return times;
}

/** 今天日期字符串，格式 YYYY-MM-DD */
export function todayDateString(): string {
  const d = new Date();
  return d.getFullYear().toString() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
}

/** 按课程名生成稳定的配色索引 */
export function colorIndexForName(name: string): number {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) % 100000;
  }
  return hash % CARD_COLORS.length;
}

/** 把时间字符串 HH:mm 解析为当天分钟数，解析失败返回 0 */
export function timeToMinutes(time: string): number {
  const parts = time.split(':');
  if (parts.length !== 2) return 0;
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  if (Number.isNaN(h) || Number.isNaN(m)) return 0;
  return h * 60 + m;
}

/** 重要程度名称 */
export const PRIORITY_NAMES: string[] = ['普通', '重要', '非常重要'];

/** 按重要程度分组的卡片配色：普通=蓝绿系，重要=橙黄系，非常重要=红紫系 */
export const PRIORITY_COLORS: string[][] = [
  ['#4C7DD9', '#2E9BA6', '#5BA054', '#4A9C7E', '#7A8B3A'],
  ['#C9772E', '#D9932E', '#B8860B'],
  ['#C25450', '#B03A48', '#8A5BC4']
];

/** 课程卡片颜色：按重要程度选色系，同名课程在同一色系内稳定分散 */
export function cardColor(priority: number, name: string): string {
  const group = priority >= 0 && priority < PRIORITY_COLORS.length
    ? PRIORITY_COLORS[priority]
    : PRIORITY_COLORS[0];
  return group[colorIndexForName(name) % group.length];
}

/** 重要程度星标：0 颗 / 1 颗 / 2 颗 */
export function priorityStars(priority: number): string {
  if (priority === 2) return '★★';
  if (priority === 1) return '★';
  return '';
}
