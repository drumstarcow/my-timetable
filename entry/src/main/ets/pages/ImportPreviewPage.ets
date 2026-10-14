import { BusinessError } from '@kit.BasicServicesKit';
import { Course, ParsedCourse } from '../common/types';
import { MAX_WEEK, colorIndexForName, WEEK_DAY_NAMES, cardColor } from '../common/constants';
import { DatabaseService } from '../services/DatabaseService';
import { ImportSession, markDataDirty } from '../services/ImportSession';
import { FieldExtractor } from '../services/FieldExtractor';
import { CourseEditDialog } from '../components/CourseEditDialog';
import { Logger } from '../common/Logger';

const TAG = 'ImportPreviewPage';

/** 导入预览页：核对解析结果，可编辑/删除/手动补充后统一入库 */
@Component
export struct ImportPreviewPage {
  @Consume('navPath') navPath: NavPathStack;
  @State source: string = '';
  @State courses: ParsedCourse[] = [];
  @State rawLines: string[] = [];
  @State gridFound: boolean = false;
  @State showEdit: boolean = false;
  @State editing: Course = {
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
  @State editingIndex: number = -1;
  @State isNew: boolean = true;
  @State saving: boolean = false;

  aboutToAppear(): void {
    const payload = ImportSession.get();
    if (payload !== undefined) {
      this.source = payload.source;
      this.courses = payload.courses;
      this.rawLines = payload.rawLines;
      this.gridFound = payload.gridFound;
    }
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private detailLabel(c: ParsedCourse): string {
    const day = c.dayOfWeek >= 1 && c.dayOfWeek <= 7 ? WEEK_DAY_NAMES[c.dayOfWeek - 1] : '?';
    let label = day + ' 第' + c.startSection.toString() + '-' + c.endSection.toString() + '节';
    const parts: string[] = [];
    if (c.room.length > 0) {
      parts.push(c.room);
    }
    if (c.teacher.length > 0) {
      parts.push(c.teacher);
    }
    let weekLabel = c.startWeek.toString() + '-' + c.endWeek.toString() + '周';
    if (c.weekType === 1) {
      weekLabel += '单';
    } else if (c.weekType === 2) {
      weekLabel += '双';
    }
    parts.push(weekLabel);
    if (parts.length > 0) {
      label += ' · ' + parts.join(' / ');
    }
    return label;
  }

  /** 点击课程项进入编辑 */
  private openEdit(c: ParsedCourse, index: number): void {
    const base: Course = {
      id: c.id,
      name: c.name,
      teacher: c.teacher,
      room: c.room,
      dayOfWeek: c.dayOfWeek,
      startSection: c.startSection,
      endSection: c.endSection,
      weekType: c.weekType,
      startWeek: c.startWeek,
      endWeek: c.endWeek,
      colorIndex: c.colorIndex,
      priority: c.priority,
      content: c.content
    };
    this.editing = base;
    this.editingIndex = index;
    this.isNew = false;
    this.showEdit = true;
  }

  /** 手动新增（预填可选原文） */
  private openAdd(prefill: string): void {
    const parsed = prefill.length > 0 ? FieldExtractor.extractCourse(prefill) : undefined;
    const base: Course = {
      name: parsed !== undefined ? parsed.name : prefill,
      teacher: parsed !== undefined ? parsed.teacher : '',
      room: parsed !== undefined ? parsed.room : '',
      dayOfWeek: 1,
      startSection: parsed !== undefined ? parsed.startSection : 1,
      endSection: parsed !== undefined ? parsed.endSection : 1,
      weekType: parsed !== undefined ? parsed.weekType : 0,
      startWeek: parsed !== undefined ? parsed.startWeek : 1,
      endWeek: parsed !== undefined ? parsed.endWeek : MAX_WEEK,
      colorIndex: colorIndexForName(prefill.length > 0 ? prefill : '新课程'),
      priority: 0,
      content: ''
    };
    this.editing = base;
    this.editingIndex = -1;
    this.isNew = true;
    this.showEdit = true;
  }

  /** 编辑保存回写列表 */
  private onEditSave(c: Course): void {
    if (this.editingIndex >= 0 && this.editingIndex < this.courses.length) {
      const old = this.courses[this.editingIndex];
      const updated: ParsedCourse = {
        id: c.id,
        name: c.name,
        teacher: c.teacher,
        room: c.room,
        dayOfWeek: c.dayOfWeek,
        startSection: c.startSection,
        endSection: c.endSection,
        weekType: c.weekType,
        startWeek: c.startWeek,
        endWeek: c.endWeek,
        colorIndex: c.colorIndex,
        priority: c.priority,
        content: c.content,
        rawText: old.rawText,
        hasSection: old.hasSection
      };
      this.courses.splice(this.editingIndex, 1, updated);
    } else {
      const added: ParsedCourse = {
        id: undefined,
        name: c.name,
        teacher: c.teacher,
        room: c.room,
        dayOfWeek: c.dayOfWeek,
        startSection: c.startSection,
        endSection: c.endSection,
        weekType: c.weekType,
        startWeek: c.startWeek,
        endWeek: c.endWeek,
        colorIndex: c.colorIndex,
        priority: 0,
        content: '',
        rawText: '',
        hasSection: true
      };
      this.courses.push(added);
    }
    this.showEdit = false;
  }

  private removeAt(index: number): void {
    this.courses.splice(index, 1);
  }

  private async saveAll(): Promise<void> {
    if (this.courses.length === 0) {
      this.toast('没有可导入的课程');
      return;
    }
    this.saving = true;
    try {
      const list: Course[] = [];
      for (const p of this.courses) {
        const c: Course = {
          name: p.name,
          teacher: p.teacher,
          room: p.room,
          dayOfWeek: p.dayOfWeek,
          startSection: p.startSection,
          endSection: p.endSection,
          weekType: p.weekType,
          startWeek: p.startWeek,
          endWeek: p.endWeek,
          colorIndex: p.colorIndex,
          priority: p.priority,
          content: p.content
        };
        list.push(c);
      }
      await DatabaseService.getInstance().insertCourses(list);
      ImportSession.clear();
      markDataDirty();
      this.toast('已导入 ' + list.length.toString() + ' 门课程');
      this.navPath.pop();
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'saveAll failed: ' + err.message);
      this.toast('保存失败：' + err.message);
    } finally {
      this.saving = false;
    }
  }

  @Builder
  CourseItem(c: ParsedCourse, index: number) {
    Row({ space: 10 }) {
      Column()
        .width(6)
        .height(40)
        .borderRadius(3)
        .backgroundColor(cardColor(c.priority, c.name))
      Column({ space: 4 }) {
        Text(c.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
        Text(this.detailLabel(c))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('删除')
        .fontSize(13)
        .fontColor($r('app.color.danger'))
        .onClick(() => {
          this.removeAt(index);
        })
    }
    .width('100%')
    .padding(12)
    .borderRadius(10)
    .backgroundColor($r('app.color.card_bg'))
    .onClick(() => {
      this.openEdit(c, index);
    })
  }

  build() {
    NavDestination() {
      Stack() {
        Column() {
          Text(this.source + '：识别到 ' + this.courses.length.toString() + ' 门课程，点击课程可修正')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })

          Scroll() {
            Column({ space: 8 }) {
              if (this.courses.length === 0 && this.gridFound) {
                Text('未识别到课程，可点击下方按钮手动添加')
                  .fontSize(14)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 30 })
              }
              ForEach(this.courses, (c: ParsedCourse, index: number) => {
                this.CourseItem(c, index)
              }, (c: ParsedCourse, index: number) => {
                return 'p' + index.toString() + '_' + c.name + '_' + c.dayOfWeek.toString() +
                  '_' + c.startSection.toString();
              })

              // 网格识别失败：展示原文逐行手动补录
              if (!this.gridFound && this.rawLines.length > 0) {
                Text('未能识别出课表网格，以下是识别原文，点击"添加"快速补录：')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .width('100%')
                  .margin({ top: 10 })
                ForEach(this.rawLines, (line: string, index: number) => {
                  Row() {
                    Text(line)
                      .fontSize(13)
                      .fontColor($r('app.color.text_primary'))
                      .layoutWeight(1)
                      .maxLines(2)
                    Text('添加')
                      .fontSize(13)
                      .fontColor($r('app.color.accent'))
                      .onClick(() => {
                        this.openAdd(line);
                      })
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .borderRadius(8)
                  .backgroundColor($r('app.color.card_bg'))
                }, (line: string, index: number) => {
                  return 'r' + index.toString() + '_' + line;
                })
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 16 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .align(Alignment.Top)

          Row({ space: 12 }) {
            Button('手动添加')
              .backgroundColor($r('app.color.card_bg'))
              .fontColor($r('app.color.accent'))
              .borderWidth(1)
              .borderColor($r('app.color.accent'))
              .onClick(() => {
                this.openAdd('');
              })
            Blank()
            Button('保存全部课程')
              .backgroundColor($r('app.color.accent'))
              .onClick(() => {
                this.saveAll();
              })
          }
          .width('100%')
          .padding(16)
        }
        .width('100%')
        .height('100%')

        // 课程编辑弹窗
        if (this.showEdit) {
          Column() {
            CourseEditDialog({
              course: this.editing,
              isNew: this.isNew,
              onSave: (c: Course) => {
                this.onEditSave(c);
              },
              onDelete: () => {
                if (this.editingIndex >= 0) {
                  this.removeAt(this.editingIndex);
                }
                this.showEdit = false;
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

        // 保存中遮罩
        if (this.saving) {
          Column({ space: 12 }) {
            LoadingProgress()
              .width(48)
              .height(48)
              .color($r('app.color.accent'))
            Text('正在保存…')
              .fontSize(14)
              .fontColor(Color.White)
          }
          .width('100%')
          .height('100%')
          .backgroundColor('#80000000')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
    }
    .title('导入预览')
    .onBackPressed(() => {
      ImportSession.clear();
      return false;
    })
  }
}
