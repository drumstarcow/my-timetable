import { Course } from './types';
import { MAX_WEEK } from './constants';

/** 返回今天星期几：周一=1 … 周日=7 */
export function getDayOfToday(): number {
  const d = new Date().getDay();
  return d === 0 ? 7 : d;
}

function parseDateString(dateStr: string): Date | undefined {
  const parts = dateStr.split('-');
  if (parts.length !== 3) return undefined;
  const y = parseInt(parts[0], 10);
  const mo = parseInt(parts[1], 10);
  const d = parseInt(parts[2], 10);
  if (Number.isNaN(y) || Number.isNaN(mo) || Number.isNaN(d)) return undefined;
  return new Date(y, mo - 1, d);
}

/**
 * 计算当前是第几周。
 * 约定：学期开始日期为第 1 周的周一。
 */
export function calcCurrentWeek(startDateStr: string): number {
  const start = parseDateString(startDateStr);
  if (start === undefined) return 1;
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const diffDays = Math.floor((today.getTime() - start.getTime()) / 86400000);
  const week = Math.floor(diffDays / 7) + 1;
  return Math.max(1, Math.min(MAX_WEEK, week));
}

/** 课程在某周是否上课（用于网格展示与非本周置灰） */
export function isCourseVisibleInWeek(c: Course, week: number): boolean {
  if (week < c.startWeek || week > c.endWeek) return false;
  if (c.weekType === 1) return week % 2 === 1;
  if (c.weekType === 2) return week % 2 === 0;
  return true;
}
