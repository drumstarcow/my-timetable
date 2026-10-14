import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x1200;

/** hilog 简单封装 */
export class Logger {
  static info(tag: string, msg: string): void {
    hilog.info(DOMAIN, tag, '%{public}s', msg);
  }

  static warn(tag: string, msg: string): void {
    hilog.warn(DOMAIN, tag, '%{public}s', msg);
  }

  static error(tag: string, msg: string): void {
    hilog.error(DOMAIN, tag, '%{public}s', msg);
  }
}
