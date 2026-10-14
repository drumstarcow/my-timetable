import { Course } from '../common/types';
import { WEEK_DAY_NAMES, WEEK_TYPE_NAMES, PRIORITY_NAMES, MAX_SECTION, MAX_WEEK, colorIndexForName } from '../common/constants';

/** 课程编辑表单（覆盖层弹窗面板，父组件控制显隐） */
@Component
export struct CourseEditDialog {
  course: Course = {
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
  isNew: boolean = true;
  onSave: (c: Course) => void = (c: Course) => {
  };
  onDelete: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @State name: string = '';
  @State teacher: string = '';
  @State room: string = '';
  @State dayIndex: number = 0;
  @State startSection: number = 1;
  @State endSection: number = 1;
  @State startWeek: string = '1';
  @State endWeek: string = MAX_WEEK.toString();
  @State weekTypeIndex: number = 0;
  @State priorityIndex: number = 0;
  @State content: string = '';

  private dayOptions: SelectOption[] = [];
  private sectionOptions: SelectOption[] = [];
  private weekTypeOptions: SelectOption[] = [];
  private priorityOptions: SelectOption[] = [];

  aboutToAppear(): void {
    this.name = this.course.name;
    this.teacher = this.course.teacher;
    this.room = this.course.room;
    this.dayIndex = this.course.dayOfWeek - 1;
    this.startSection = this.course.startSection;
    this.endSection = this.course.endSection;
    this.startWeek = this.course.startWeek.toString();
    this.endWeek = this.course.endWeek.toString();
    this.weekTypeIndex = this.course.weekType;
    this.priorityIndex = this.course.priority >= 0 && this.course.priority <= 2 ? this.course.priority : 0;
    this.content = this.course.content;
    for (const n of WEEK_DAY_NAMES) {
      this.dayOptions.push({ value: n });
    }
    for (let i = 1; i <= MAX_SECTION; i++) {
      this.sectionOptions.push({ value: '第 ' + i.toString() + ' 节' });
    }
    for (const n of WEEK_TYPE_NAMES) {
      this.weekTypeOptions.push({ value: n });
    }
    for (const n of PRIORITY_NAMES) {
      this.priorityOptions.push({ value: n });
    }
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private save(): void {
    const nm = this.name.trim();
    if (nm.length === 0) {
      this.toast('请填写课程名称');
      return;
    }
    const sw = parseInt(this.startWeek, 10);
    const ew = parseInt(this.endWeek, 10);
    if (Number.isNaN(sw) || Number.isNaN(ew) || sw < 1 || ew < sw || ew > MAX_WEEK) {
      this.toast('周次范围不正确（1-' + MAX_WEEK.toString() + '）');
      return;
    }
    const c: Course = {
      id: this.course.id,
      name: nm,
      teacher: this.teacher.trim(),
      room: this.room.trim(),
      dayOfWeek: this.dayIndex + 1,
      startSection: Math.min(this.startSection, this.endSection),
      endSection: Math.max(this.startSection, this.endSection),
      weekType: this.weekTypeIndex,
      startWeek: sw,
      endWeek: ew,
      colorIndex: nm === this.course.name ? this.course.colorIndex : colorIndexForName(nm),
      priority: this.priorityIndex,
      content: this.content
    };
    this.onSave(c);
  }

  build() {
    Column({ space: 12 }) {
      Text(this.isNew ? '新增课程' : '编辑课程')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Scroll() {
        Column({ space: 10 }) {
          Text('课程名称').fontSize(13).fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.name, placeholder: '如：高等数学' })
            .onChange((v: string) => {
              this.name = v;
            })

          Row() {
            Text('星期').fontSize(13).fontColor($r('app.color.text_secondary')).width(70)
            Select(this.dayOptions)
              .selected(this.dayIndex)
              .value(WEEK_DAY_NAMES[this.dayIndex])
              .onSelect((index: number) => {
                this.dayIndex = index;
              })
              .layoutWeight(1)
          }

          Row() {
            Text('节次').fontSize(13).fontColor($r('app.color.text_secondary')).width(70)
            Select(this.sectionOptions)
              .selected(this.startSection - 1)
              .value('第 ' + this.startSection.toString() + ' 节')
              .onSelect((index: number) => {
                this.startSection = index + 1;
              })
              .layoutWeight(1)
            Text('至').fontSize(13).margin({ left: 8, right: 8 })
            Select(this.sectionOptions)
              .selected(this.endSection - 1)
              .value('第 ' + this.endSection.toString() + ' 节')
              .onSelect((index: number) => {
                this.endSection = index + 1;
              })
              .layoutWeight(1)
          }

          Row() {
            Text('周次').fontSize(13).fontColor($r('app.color.text_secondary')).width(70)
            TextInput({ text: this.startWeek })
              .type(InputType.Number)
              .width(80)
              .onChange((v: string) => {
                this.startWeek = v;
              })
            Text('至').fontSize(13).margin({ left: 8, right: 8 })
            TextInput({ text: this.endWeek })
              .type(InputType.Number)
              .width(80)
              .onChange((v: string) => {
                this.endWeek = v;
              })
            Blank()
          }

          Row() {
            Text('周类型').fontSize(13).fontColor($r('app.color.text_secondary')).width(70)
            Select(this.weekTypeOptions)
              .selected(this.weekTypeIndex)
              .value(WEEK_TYPE_NAMES[this.weekTypeIndex])
              .onSelect((index: number) => {
                this.weekTypeIndex = index;
              })
              .layoutWeight(1)
          }

          Row() {
            Text('重要程度').fontSize(13).fontColor($r('app.color.text_secondary')).width(70)
            Select(this.priorityOptions)
              .selected(this.priorityIndex)
              .value(PRIORITY_NAMES[this.priorityIndex])
              .onSelect((index: number) => {
                this.priorityIndex = index;
              })
              .layoutWeight(1)
          }

          Text('教师（选填）').fontSize(13).fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.teacher, placeholder: '如：张老师' })
            .onChange((v: string) => {
              this.teacher = v;
            })

          Text('教室（选填）').fontSize(13).fontColor($r('app.color.text_secondary'))
          TextInput({ text: this.room, placeholder: '如：教1-201' })
            .onChange((v: string) => {
              this.room = v;
            })

          Text('课程内容（选填）').fontSize(13).fontColor($r('app.color.text_secondary'))
          TextArea({ text: this.content, placeholder: '如：本课程主要讲述……' })
            .height(90)
            .onChange((v: string) => {
              this.content = v;
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .constraintSize({ maxHeight: 420 })
      .scrollBar(BarState.Auto)

      Row({ space: 10 }) {
        if (!this.isNew) {
          Button('删除课程')
            .backgroundColor($r('app.color.danger'))
            .onClick(() => {
              this.onDelete();
            })
        }
        Blank()
        Button('取消')
          .backgroundColor($r('app.color.divider'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.onClose();
          })
        Button('保存')
          .backgroundColor($r('app.color.accent'))
          .onClick(() => {
            this.save();
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .width(480)
    .alignItems(HorizontalAlign.Start)
  }
}
