import { Course } from '../common/types';
import { GRID_ROW_HEIGHT, MAX_WEEK, cardColor, priorityStars } from '../common/constants';
import { isCourseVisibleInWeek } from '../common/WeekCalculator';

/** 周网格中的课程卡片：按起止节次定位，非本周课程置灰 */
@Component
export struct CourseCard {
  @Prop course: Course = {
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
  @Prop week: number = 1;
  onEdit: (c: Course) => void = (c: Course) => {
  };

  private weeksLabel(): string {
    if (this.course.weekType === 0 && this.course.startWeek <= 1 && this.course.endWeek >= MAX_WEEK) {
      return '全部周';
    }
    let label = this.course.startWeek.toString() + '-' + this.course.endWeek.toString() + '周';
    if (this.course.weekType === 1) {
      label += '单';
    } else if (this.course.weekType === 2) {
      label += '双';
    }
    return label;
  }

  build() {
    Column({ space: 2 }) {
      if (this.course.priority > 0) {
        Text(priorityStars(this.course.priority))
          .fontSize(11)
          .fontColor('#FFE066')
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      Text(this.course.name)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .maxLines(3)
        .textAlign(TextAlign.Center)
        .width('100%')
      if (this.course.room.length > 0) {
        Text(this.course.room)
          .fontSize(11)
          .fontColor('#EAEAEA')
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      if (this.course.teacher.length > 0) {
        Text(this.course.teacher)
          .fontSize(11)
          .fontColor('#EAEAEA')
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .width('100%')
      }
      Text(this.weeksLabel())
        .fontSize(10)
        .fontColor('#DDDDDD')
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height((this.course.endSection - this.course.startSection + 1) * GRID_ROW_HEIGHT - 8)
    .backgroundColor(cardColor(this.course.priority, this.course.name))
    .borderRadius(8)
    .padding(4)
    .opacity(isCourseVisibleInWeek(this.course, this.week) ? 1.0 : 0.35)
    .onClick(() => {
      this.onEdit(this.course);
    })
  }
}
