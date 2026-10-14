import { relationalStore } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { SectionTime } from '../common/types';
import { DEFAULT_SECTION_COUNT, defaultSectionTimes, todayDateString } from '../common/constants';
import { DatabaseService } from './DatabaseService';
import { Logger } from '../common/Logger';

/** 应用设置 */
export interface AppSettings {
  /** 学期开始日期（第 1 周周一），格式 YYYY-MM-DD */
  semesterStartDate: string;
  /** 节次时间表 */
  sectionTimes: SectionTime[];
}

const TAG = 'SettingsService';
const KEY_START_DATE = 'semester_start_date';
const KEY_SECTION_TIMES = 'section_times';

/** 设置单例：学期开始日期与节次时间表，持久化于 app_setting 表 */
export class SettingsService {
  private static instance: SettingsService | undefined = undefined;

  static getInstance(): SettingsService {
    if (SettingsService.instance === undefined) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }

  private cache: AppSettings | undefined = undefined;

  private constructor() {
  }

  async getSettings(): Promise<AppSettings> {
    if (this.cache !== undefined) {
      return this.cache;
    }
    let startDate = todayDateString();
    let times = defaultSectionTimes(DEFAULT_SECTION_COUNT);
    try {
      const store = await DatabaseService.getInstance().getStore();
      const rs = await store.query(new relationalStore.RdbPredicates('app_setting'));
      while (rs.goToNextRow()) {
        const key = rs.getString(rs.getColumnIndex('key'));
        const value = rs.getString(rs.getColumnIndex('value'));
        if (key === KEY_START_DATE && value.length >= 8) {
          startDate = value;
        } else if (key === KEY_SECTION_TIMES) {
          const parsed = JSON.parse(value) as SectionTime[];
          if (parsed.length > 0) {
            times = parsed;
          }
        }
      }
      rs.close();
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'getSettings failed: ' + err.message);
    }
    const settings: AppSettings = {
      semesterStartDate: startDate,
      sectionTimes: times
    };
    this.cache = settings;
    Logger.info(TAG, 'getSettings returning, sections=' + settings.sectionTimes.length.toString());
    return settings;
  }

  async saveSettings(s: AppSettings): Promise<void> {
    const store = await DatabaseService.getInstance().getStore();
    await this.upsert(store, KEY_START_DATE, s.semesterStartDate);
    await this.upsert(store, KEY_SECTION_TIMES, JSON.stringify(s.sectionTimes));
    this.cache = s;
  }

  /** 节次时间表整体更新（设置页增删节次） */
  async updateSectionTimes(times: SectionTime[]): Promise<void> {
    const s = await this.getSettings();
    const updated: AppSettings = {
      semesterStartDate: s.semesterStartDate,
      sectionTimes: times
    };
    await this.saveSettings(updated);
  }

  private async upsert(store: relationalStore.RdbStore, key: string, value: string): Promise<void> {
    const bucket: relationalStore.ValuesBucket = {
      'key': key,
      'value': value
    };
    try {
      await store.insert('app_setting', bucket);
    } catch (e) {
      // 主键冲突说明已存在，改为更新
      const predicates = new relationalStore.RdbPredicates('app_setting');
      predicates.equalTo('key', key);
      await store.update(bucket, predicates);
    }
  }
}
