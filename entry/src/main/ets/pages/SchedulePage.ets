import { BusinessError } from '@kit.BasicServicesKit';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';
import { Course, SectionTime, ImportPayload } from '../common/types';
import { MAX_WEEK, GRID_HEADER_HEIGHT } from '../common/constants';
import { getDayOfToday, calcCurrentWeek } from '../common/WeekCalculator';
import { DatabaseService } from '../services/DatabaseService';
import { SettingsService } from '../services/SettingsService';
import { ImportSession, clearDataDirty } from '../services/ImportSession';
import { OcrService } from '../services/OcrService';
import { ScheduleParser } from '../services/ScheduleParser';
import { MatrixParser } from '../services/MatrixParser';
import { CsvParser } from '../services/CsvParser';
import { ExcelParser } from '../services/ExcelParser';
import { WeekSwitchBar } from '../components/WeekSwitchBar';
import { WeekGrid } from '../components/WeekGrid';
import { CourseEditDialog } from '../components/CourseEditDialog';
import { CourseDetailDialog } from '../components/CourseDetailDialog';
import { ImportSourceDialog } from '../components/ImportSourceDialog';
import { PolicySection, getPrivacySections } from '../common/PrivacyText';
import { Logger } from '../common/Logger';

const TAG = 'SchedulePage';

/** 主页：周视图课表 + 导入/设置入口 + 覆盖层弹窗管理 */
@Component
export struct SchedulePage {
  @Consume('navPath') navPath: NavPathStack;

  @State courses: Course[] = [];
  @State week: number = 1;
  @State currentWeek: number = 1;
  @State sectionTimes: SectionTime[] = [];
  @State showSource: boolean = false;
  @State showEdit: boolean = false;
  @State showDetail: boolean = false;
  @State detailCourse: Course = {
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
    content: ''
  };
  @State editingCourse: Course = {
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
    content: ''
  };
  @State isNewCourse: boolean = true;
  @State busy: boolean = false;
  @State showPrivacy: boolean = false;
  private privacySections: PolicySection[] = getPrivacySections();
  @StorageLink('schedule_data_dirty') @Watch('onDataDirty') dataDirty: boolean = false;

  private today: number = getDayOfToday();

  aboutToAppear(): void {
    Logger.info(TAG, 'aboutToAppear begin');
    clearDataDirty();
    this.reload();
    SettingsService.getInstance().isPrivacyAgreed().then((agreed: boolean) => {
      this.showPrivacy = !agreed;
      Logger.info(TAG, 'privacy agreed=' + agreed.toString());
    });
  }

  /** 同意隐私政策：记录标记并进入应用 */
  private agreePrivacy(): void {
    SettingsService.getInstance().setPrivacyAgreed().then(() => {
      this.showPrivacy = false;
      Logger.info(TAG, 'privacy agreed saved');
    }).catch((e: BusinessError) => {
      Logger.error(TAG, 'agreePrivacy failed: ' + e.message);
      this.showPrivacy = false;
    });
  }

  /** 不同意隐私政策：退出应用 */
  private declinePrivacy(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ctx.terminateSelf().catch((e: BusinessError) => {
      Logger.error(TAG, 'terminateSelf failed: ' + e.message);
    });
  }

  /** 数据变更标记（导入预览页保存后）触发刷新 */
  onDataDirty(): void {
    if (this.dataDirty) {
      this.dataDirty = false;
      this.reload();
    }
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  /** 保存课程自由备注（详情弹窗"保存备注"，仅更新 note 列） */
  private async saveNote(note: string): Promise<void> {
    if (this.detailCourse.id === undefined) {
      return;
    }
    try {
      await DatabaseService.getInstance().updateCourseNote(this.detailCourse.id, note);
      this.detailCourse.note = note;
      this.toast('备注已保存');
      this.reload();
    } catch (e) {
      const err = e as Error;
      Logger.error(TAG, 'saveNote failed: ' + err.message);
      this.toast('保存失败');
    }
  }

  private async reload(): Promise<void> {
    Logger.info(TAG, 'reload begin');
    const settings = await SettingsService.getInstance().getSettings();
    Logger.info(TAG, 'reload settings ok, sections=' + settings.sectionTimes.length.toString());
    this.sectionTimes = settings.sectionTimes;
    this.currentWeek = calcCurrentWeek(settings.semesterStartDate);
    this.week = this.currentWeek;
    this.courses = await DatabaseService.getInstance().queryAllCourses();
    Logger.info(TAG, 'reload done, courses=' + this.courses.length.toString());
  }

  private async saveCourse(c: Course): Promise<void> {
    try {
      if (c.id !== undefined) {
        await DatabaseService.getInstance().updateCourse(c);
      } else {
        await DatabaseService.getInstance().insertCourse(c);
      }
      this.showEdit = false;
      await this.reload();
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'saveCourse failed: ' + err.message);
      this.toast('保存失败：' + err.message);
    }
  }

  private async removeCourse(c: Course): Promise<void> {
    try {
      if (c.id !== undefined) {
        await DatabaseService.getInstance().deleteCourse(c.id);
      }
      this.showEdit = false;
      await this.reload();
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'removeCourse failed: ' + err.message);
      this.toast('删除失败：' + err.message);
    }
  }

  /** 图片识别导入：OCR -> 网格解析 -> 预览页 */
  private async importFromImage(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.showSource = false;
    this.busy = true;
    try {
      const outcome = await OcrService.pickAndRecognize();
      if (outcome === undefined) {
        return;
      }
      const result = ScheduleParser.parseOcr(outcome.lines);
      const payload: ImportPayload = {
        source: '图片识别',
        courses: result.courses,
        rawLines: result.rawLines,
        gridFound: result.gridFound
      };
      ImportSession.set(payload);
      this.navPath.pushPathByName('importPreview', undefined);
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'importFromImage failed: ' + err.message);
      this.toast('图片识别失败：' + err.message);
    } finally {
      this.busy = false;
    }
  }

  /** 文件导入：CSV / xlsx -> 矩阵解析 -> 预览页 */
  private async importFromFile(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.showSource = false;
    const docPicker = new picker.DocumentViewPicker();
    const opts: picker.DocumentSelectOptions = {
      fileSuffixFilters: ['课表文件|.csv,.xlsx'],
      maxSelectNumber: 1
    };
    let uris: Array<string> = [];
    try {
      uris = await docPicker.select(opts);
    } catch (e) {
      Logger.warn(TAG, 'document picker cancelled');
    }
    if (uris.length === 0) {
      return;
    }
    const uri = uris[0];
    const isXlsx = uri.toLowerCase().endsWith('.xlsx');
    this.busy = true;
    try {
      const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
      let buffer: ArrayBuffer;
      try {
        const stat = await fs.stat(file.fd);
        buffer = new ArrayBuffer(stat.size);
        await fs.read(file.fd, buffer);
      } finally {
        await fs.close(file.fd);
      }

      let matrix: string[][] = [];
      let sourceName = '';
      if (isXlsx) {
        const ctx = this.getUIContext().getHostContext();
        const cacheDir = ctx !== undefined ? ctx.cacheDir : '';
        matrix = await ExcelParser.parseToMatrix(buffer, cacheDir);
        sourceName = 'Excel 导入';
      } else {
        const text = CsvParser.decodeUtf8(buffer);
        if (CsvParser.looksLikeGarbled(text)) {
          this.toast('文件编码不是 UTF-8，请用记事本另存为 UTF-8 后重试');
          return;
        }
        matrix = CsvParser.parse(text);
        sourceName = 'CSV 导入';
      }
      if (matrix.length === 0) {
        this.toast('文件内容为空');
        return;
      }
      const result = MatrixParser.parseMatrix(matrix);
      const payload: ImportPayload = {
        source: sourceName,
        courses: result.courses,
        rawLines: result.rawLines,
        gridFound: result.gridFound
      };
      ImportSession.set(payload);
      this.navPath.pushPathByName('importPreview', undefined);
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'importFromFile failed: ' + err.message);
      this.toast('文件解析失败：' + err.message);
    } finally {
      this.busy = false;
    }
  }

  private openManualAdd(): void {
    this.showSource = false;
    const blank: Course = {
      name: '',
      teacher: '',
      room: '',
      dayOfWeek: 1,
      startSection: 1,
      endSection: 1,
      weekType: 0,
      startWeek: this.currentWeek,
      endWeek: MAX_WEEK,
      colorIndex: 0,
      priority: 0,
      content: ''
    };
    this.editingCourse = blank;
    this.isNewCourse = true;
    this.showEdit = true;
  }

  build() {
    Stack() {
      Column() {
        // 顶栏
        Row() {
          Text('我的课表')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text('导入')
            .fontSize(14)
            .fontColor($r('app.color.accent'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(8)
            .backgroundColor($r('app.color.card_bg'))
            .onClick(() => {
              this.showSource = true;
            })
          Text('设置')
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(8)
            .backgroundColor($r('app.color.card_bg'))
            .margin({ left: 10 })
            .onClick(() => {
              this.navPath.pushPathByName('settings', undefined);
            })
        }
        .width('100%')
        .height(GRID_HEADER_HEIGHT)
        .padding({ left: 16, right: 16 })

        WeekSwitchBar({
          week: this.week,
          currentWeek: this.currentWeek,
          onWeekChange: (w: number) => {
            this.week = w;
          }
        })
        .margin({ top: 6, bottom: 6 })

        if (this.courses.length === 0) {
          Column() {
            Text('课表还是空的')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Text('点击右上角「导入」，用图片、CSV 或 Excel 一键导入你的课程表')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 10 })
          }
          .width('100%')
          .padding({ top: 40, bottom: 16 })
          .alignItems(HorizontalAlign.Center)
        }

        WeekGrid({
          courses: this.courses,
          week: this.week,
          currentWeek: this.currentWeek,
          sectionTimes: this.sectionTimes,
          today: this.today,
          onCourseClick: (c: Course) => {
            this.detailCourse = c;
            this.showDetail = true;
          }
        })
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))

      // 导入方式选择弹窗
      if (this.showSource) {
        Column() {
          ImportSourceDialog({
            onPickImage: () => {
              this.importFromImage();
            },
            onPickFile: () => {
              this.importFromFile();
            },
            onManual: () => {
              this.openManualAdd();
            },
            onClose: () => {
              this.showSource = false;
            }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showSource = false;
        })
      }

      // 课程详情弹窗
      if (this.showDetail) {
        Column() {
          CourseDetailDialog({
            course: this.detailCourse,
            onEdit: () => {
              this.editingCourse = this.detailCourse;
              this.isNewCourse = false;
              this.showDetail = false;
              this.showEdit = true;
            },
            onClose: () => {
              this.showDetail = false;
            },
            onSaveNote: (note: string) => {
              this.saveNote(note);
            }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .justifyContent(FlexAlign.Center)
      }

      // 课程编辑弹窗
      if (this.showEdit) {
        Column() {
          CourseEditDialog({
            course: this.editingCourse,
            isNew: this.isNewCourse,
            onSave: (c: Course) => {
              this.saveCourse(c);
            },
            onDelete: () => {
              this.removeCourse(this.editingCourse);
            },
            onClose: () => {
              this.showEdit = false;
            }
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .justifyContent(FlexAlign.Center)
      }

      // 处理中遮罩
      if (this.busy) {
        Column({ space: 12 }) {
          LoadingProgress()
            .width(48)
            .height(48)
            .color($r('app.color.accent'))
          Text('正在处理…')
            .fontSize(14)
            .fontColor(Color.White)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .justifyContent(FlexAlign.Center)
      }

      // 首次启动隐私政策（必须选择同意或退出）
      if (this.showPrivacy) {
        Column() {
          Column({ space: 10 }) {
            Text('隐私政策')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Scroll() {
              Column({ space: 10 }) {
                Text('欢迎使用"杉课"。在使用前请阅读并同意以下协议：')
                  .fontSize(13)
                  .lineHeight(20)
                  .fontColor($r('app.color.text_secondary'))
                Text('核心承诺：本应用是一款纯本地工具应用。我们不收集、不存储、不上传您的任何个人信息，应用不需要联网即可使用全部功能，也不申请任何系统权限。')
                  .fontSize(13)
                  .lineHeight(20)
                  .fontColor($r('app.color.text_primary'))
                ForEach(this.privacySections, (s: PolicySection) => {
                  Column({ space: 4 }) {
                    Text(s.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                    ForEach(s.lines, (line: string) => {
                      Text(line)
                        .fontSize(12)
                        .lineHeight(19)
                        .fontColor($r('app.color.text_secondary'))
                    }, (line: string) => {
                      return line;
                    })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                }, (s: PolicySection) => {
                  return s.title;
                })
              }
              .width('100%')
            }
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
            .align(Alignment.Top)
            Row({ space: 12 }) {
              Text('不同意并退出')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .padding({ left: 18, right: 18, top: 9, bottom: 9 })
                .borderRadius(8)
                .backgroundColor($r('app.color.divider'))
                .onClick(() => {
                  this.declinePrivacy();
                })
              Text('同意并继续')
                .fontSize(14)
                .fontColor(Color.White)
                .padding({ left: 18, right: 18, top: 9, bottom: 9 })
                .borderRadius(8)
                .backgroundColor($r('app.color.accent'))
                .onClick(() => {
                  this.agreePrivacy();
                })
            }
          }
          .width('86%')
          .height('72%')
          .padding(18)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_bg'))
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#A0000000')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
