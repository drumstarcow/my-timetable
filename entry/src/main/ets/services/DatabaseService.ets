import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Course } from '../common/types';
import { markDataDirty } from './ImportSession';
import { Logger } from '../common/Logger';

const TAG = 'DatabaseService';

const SQL_CREATE_COURSE: string = `CREATE TABLE IF NOT EXISTS course (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  teacher TEXT NOT NULL DEFAULT '',
  room TEXT NOT NULL DEFAULT '',
  day_of_week INTEGER NOT NULL,
  start_section INTEGER NOT NULL,
  end_section INTEGER NOT NULL,
  week_type INTEGER NOT NULL DEFAULT 0,
  start_week INTEGER NOT NULL DEFAULT 1,
  end_week INTEGER NOT NULL DEFAULT 25,
  color_index INTEGER NOT NULL DEFAULT 0,
  priority INTEGER NOT NULL DEFAULT 0,
  content TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT ''
)`;

const SQL_CREATE_SETTING: string = `CREATE TABLE IF NOT EXISTS app_setting (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)`;

/**
 * 数据库单例：course 表 CRUD 与 app_setting 表访问。
 * 在 EntryAbility.onCreate 调用 init()，之后各方法内部 ensureReady() 防竞态。
 */
export class DatabaseService {
  private static instance: DatabaseService | undefined = undefined;

  static getInstance(): DatabaseService {
    if (DatabaseService.instance === undefined) {
      DatabaseService.instance = new DatabaseService();
    }
    return DatabaseService.instance;
  }

  private store: relationalStore.RdbStore | undefined = undefined;
  private readyPromise: Promise<void> | undefined = undefined;

  private constructor() {
  }

  /** 在 EntryAbility.onCreate 中调用一次 */
  init(context: common.UIAbilityContext): void {
    if (this.readyPromise !== undefined) {
      return;
    }
    this.readyPromise = this.doInit(context);
    this.readyPromise.catch((e: BusinessError) => {
      Logger.error(TAG, 'init failed: ' + e.message);
    });
  }

  private async doInit(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: 'course.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    this.store = await relationalStore.getRdbStore(context, config);
    await this.store.executeSql(SQL_CREATE_COURSE);
    await this.store.executeSql(SQL_CREATE_SETTING);
    // 旧版本数据库迁移：补 priority 列（已存在时抛错，忽略即可）
    try {
      await this.store.executeSql('ALTER TABLE course ADD COLUMN priority INTEGER NOT NULL DEFAULT 0');
    } catch (e) {
      Logger.info(TAG, 'priority column already exists, skip migration');
    }
    // 旧版本数据库迁移：补 content 列
    try {
      await this.store.executeSql("ALTER TABLE course ADD COLUMN content TEXT NOT NULL DEFAULT ''");
    } catch (e) {
      Logger.info(TAG, 'content column already exists, skip migration');
    }
    // 旧版本数据库迁移：补 note（用户自由备注）列
    try {
      await this.store.executeSql("ALTER TABLE course ADD COLUMN note TEXT NOT NULL DEFAULT ''");
    } catch (e) {
      Logger.info(TAG, 'note column already exists, skip migration');
    }
    Logger.info(TAG, 'database ready');
  }

  private async ensureReady(): Promise<relationalStore.RdbStore> {
    if (this.readyPromise === undefined) {
      throw new Error('DatabaseService 未初始化');
    }
    await this.readyPromise;
    if (this.store === undefined) {
      throw new Error('数据库不可用');
    }
    return this.store;
  }

  /** 供 SettingsService 复用同一数据库连接 */
  async getStore(): Promise<relationalStore.RdbStore> {
    return this.ensureReady();
  }

  private courseToBucket(c: Course): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {
      'name': c.name,
      'teacher': c.teacher,
      'room': c.room,
      'day_of_week': c.dayOfWeek,
      'start_section': c.startSection,
      'end_section': c.endSection,
      'week_type': c.weekType,
      'start_week': c.startWeek,
      'end_week': c.endWeek,
      'color_index': c.colorIndex,
      'priority': c.priority,
      'content': c.content,
      'note': c.note !== undefined ? c.note : ''
    };
    return bucket;
  }

  async queryAllCourses(): Promise<Course[]> {
    const courses: Course[] = [];
    try {
      const store = await this.ensureReady();
      const predicates = new relationalStore.RdbPredicates('course');
      predicates.orderByAsc('day_of_week').orderByAsc('start_section');
      const rs = await store.query(predicates);
      while (rs.goToNextRow()) {
        const c: Course = {
          id: rs.getLong(rs.getColumnIndex('id')),
          name: rs.getString(rs.getColumnIndex('name')),
          teacher: rs.getString(rs.getColumnIndex('teacher')),
          room: rs.getString(rs.getColumnIndex('room')),
          dayOfWeek: rs.getLong(rs.getColumnIndex('day_of_week')),
          startSection: rs.getLong(rs.getColumnIndex('start_section')),
          endSection: rs.getLong(rs.getColumnIndex('end_section')),
          weekType: rs.getLong(rs.getColumnIndex('week_type')),
          startWeek: rs.getLong(rs.getColumnIndex('start_week')),
          endWeek: rs.getLong(rs.getColumnIndex('end_week')),
          colorIndex: rs.getLong(rs.getColumnIndex('color_index')),
          priority: rs.getLong(rs.getColumnIndex('priority')),
          content: rs.getString(rs.getColumnIndex('content')),
          note: rs.getString(rs.getColumnIndex('note'))
        };
        courses.push(c);
      }
      rs.close();
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'queryAllCourses failed: ' + err.message);
    }
    Logger.info(TAG, 'queryAllCourses returning ' + courses.length.toString() + ' rows');
    return courses;
  }

  async insertCourse(c: Course): Promise<number> {
    const store = await this.ensureReady();
    return await store.insert('course', this.courseToBucket(c));
  }

  async insertCourses(list: Course[]): Promise<void> {
    for (const c of list) {
      try {
        await this.insertCourse(c);
      } catch (e) {
        const err = e as BusinessError;
        Logger.error(TAG, 'insertCourse failed: ' + err.message);
      }
    }
  }

  async updateCourse(c: Course): Promise<void> {
    if (c.id === undefined) {
      return;
    }
    const store = await this.ensureReady();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', c.id);
    await store.update(this.courseToBucket(c), predicates);
  }

  async deleteCourse(id: number): Promise<void> {
    const store = await this.ensureReady();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', id);
    await store.delete(predicates);
  }

  /** 仅更新课程备注列（详情弹窗自由备注用，不覆盖其他字段） */
  async updateCourseNote(id: number, note: string): Promise<void> {
    const store = await this.ensureReady();
    const predicates = new relationalStore.RdbPredicates('course');
    predicates.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { 'note': note };
    await store.update(bucket, predicates);
  }
}
