import { ImportPayload } from '../common/types';

/**
 * 导入数据中转站：解析结果从主页传递到预览页。
 * 数据量可能较大且含 OCR 中间结果，不走路由参数。
 */
export class ImportSession {
  private static payload: ImportPayload | undefined = undefined;

  static set(p: ImportPayload): void {
    ImportSession.payload = p;
  }

  static get(): ImportPayload | undefined {
    return ImportSession.payload;
  }

  static clear(): void {
    ImportSession.payload = undefined;
  }
}

/** AppStorage 键：课表数据变更标记（主页据此自动刷新），装饰器中需用字面量 */
export const KEY_DATA_DIRTY: string = 'schedule_data_dirty';

/** 任何增删改后调用，主页监听此标记刷新数据 */
export function markDataDirty(): void {
  AppStorage.setOrCreate('schedule_data_dirty', true);
}

/** 主页刷新完成后清除标记 */
export function clearDataDirty(): void {
  AppStorage.setOrCreate('schedule_data_dirty', false);
}
