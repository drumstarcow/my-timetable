import { Course } from '../common/types';
import { WEEK_DAY_NAMES, MAX_WEEK, cardColor, priorityStars } from '../common/constants';

/** 课程详情弹窗：展示任课老师、教室、时间与课程内容 */
@Component
export struct CourseDetailDialog {
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
  onEdit: () => void = () => {
  };
  onClose: () => void = () => {
  };

  private weekLabel(): string {
    if (this.course.weekType === 0 && this.course.startWeek <= 1 && this.course.endWeek >= MAX_WEEK) {
      return '每周';
    }
    let label = this.course.startWeek.toString() + ' - ' + this.course.endWeek.toString() + ' 周';
    if (this.course.weekType === 1) {
      label += '（单周）';
    } else if (this.course.weekType === 2) {
      label += '（双周）';
    }
    return label;
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(68)
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
  }

  build() {
    Column({ space: 14 }) {
      // 标题行：色块 + 课程名 + 星标
      Row({ space: 10 }) {
        Column()
          .width(10)
          .height(30)
          .borderRadius(4)
          .backgroundColor(cardColor(this.course.priority, this.course.name))
        Text(this.course.name)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(2)
        if (this.course.priority > 0) {
          Text(priorityStars(this.course.priority))
            .fontSize(14)
            .fontColor('#D9990B')
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      this.InfoRow('任课老师', this.course.teacher.length > 0 ? this.course.teacher : '—')
      this.InfoRow('上课教室', this.course.room.length > 0 ? this.course.room : '—')
      this.InfoRow('上课时间',
        WEEK_DAY_NAMES[this.course.dayOfWeek - 1] + ' 第' + this.course.startSection.toString() +
        '-' + this.course.endSection.toString() + '节')
      this.InfoRow('周次', this.weekLabel())

      // 课程内容
      Column({ space: 6 }) {
        Text('课程内容')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
        if (this.course.content.length > 0) {
          Text(this.course.content)
            .fontSize(14)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
        } else {
          Text('暂无课程内容描述，点击"编辑"可补充')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .fontStyle(FontStyle.Italic)
        }
      }
      .width('100%')
      .padding(10)
      .borderRadius(8)
      .backgroundColor($r('app.color.page_bg'))
      .alignItems(HorizontalAlign.Start)

      Row({ space: 10 }) {
        Button('编辑')
          .layoutWeight(1)
          .backgroundColor($r('app.color.accent'))
          .onClick(() => {
            this.onEdit();
          })
        Button('关闭')
          .layoutWeight(1)
          .backgroundColor($r('app.color.divider'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => {
            this.onClose();
          })
      }
      .width('100%')
    }
    .padding(20)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .width(400)
  }
}
