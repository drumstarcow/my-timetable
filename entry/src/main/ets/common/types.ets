/**
 * 通用数据类型定义
 */

/** 课程实体（对应 course 表） */
export interface Course {
  /** 数据库主键，未入库时为 undefined */
  id?: number;
  /** 课程名（必填） */
  name: string;
  teacher: string;
  room: string;
  /** 星期几：1~7，周一=1 */
  dayOfWeek: number;
  /** 起始节次，从 1 开始 */
  startSection: number;
  /** 结束节次，>= startSection */
  endSection: number;
  /** 上课周类型：0=每周 1=单周 2=双周 */
  weekType: number;
  /** 起始周 */
  startWeek: number;
  /** 结束周 */
  endWeek: number;
  /** 课程卡片配色索引（取 CARD_COLORS 的下标） */
  colorIndex: number;
  /** 重要程度：0=普通 1=重要 2=非常重要（决定卡片颜色分组与星标） */
  priority: number;
  /** 课程内容描述（讲述内容等，选填） */
  content: string;
}

/** 导入解析过程中产生的课程（附带原始单元格文本，便于核对修正） */
export interface ParsedCourse extends Course {
  rawText: string;
  /** 文本中是否显式出现节次（用于网格行带校正时判断是否覆盖） */
  hasSection?: boolean;
}

/** 单节次的起止时间，如 08:00 / 08:45 */
export interface SectionTime {
  start: string;
  end: string;
}

/** OCR 识别出的一行文字（含左上角坐标与尺寸，单位像素） */
export interface OcrLine {
  text: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

/** 课表解析结果 */
export interface ParseResult {
  courses: ParsedCourse[];
  /** 识别全文按行拆分（网格识别失败时的降级展示数据） */
  rawLines: string[];
  /** 是否成功识别出课表网格 */
  gridFound: boolean;
}

/** 导入流程的中转载荷（解析页 -> 预览页） */
export interface ImportPayload {
  /** 来源描述，如 "图片识别" / "CSV 导入" / "Excel 导入" */
  source: string;
  courses: ParsedCourse[];
  rawLines: string[];
  gridFound: boolean;
}
