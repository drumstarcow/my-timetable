import { Course, SectionTime } from '../common/types';
import { GRID_ROW_HEIGHT, GRID_HEADER_HEIGHT, GRID_SECTION_COL_WIDTH, WEEK_DAY_NAMES, MAX_WEEK } from '../common/constants';
import { CourseCard } from './CourseCard';

/** 周视图网格：左侧节次时间列 + 周一~周日 7 等分课程列，竖向滚动 */
@Component
export struct WeekGrid {
  @Prop courses: Course[] = [];
  @Prop week: number = 1;
  @Prop currentWeek: number = 1;
  @Prop sectionTimes: SectionTime[] = [];
  @Prop today: number = 1;
  onCourseClick: (c: Course) => void = (c: Course) => {
  };

  private isToday(day: number): boolean {
    return this.week === this.currentWeek && day === this.today;
  }

  /** 结束节次不超过实际节次数，起始节次超界的课程不显示 */
  private dayCourses(day: number): Course[] {
    const maxSection = Math.max(1, this.sectionTimes.length);
    const out: Course[] = [];
    for (const c of this.courses) {
      if (c.dayOfWeek !== day || c.startSection > maxSection) {
        continue;
      }
      const fixed: Course = {
        id: c.id,
        name: c.name,
        teacher: c.teacher,
        room: c.room,
        dayOfWeek: c.dayOfWeek,
        startSection: c.startSection,
        endSection: Math.min(c.endSection, maxSection),
        weekType: c.weekType,
        startWeek: c.startWeek,
        endWeek: Math.min(c.endWeek, MAX_WEEK),
        colorIndex: c.colorIndex,
        priority: c.priority,
        content: c.content
      };
      out.push(fixed);
    }
    return out;
  }

  build() {
    Scroll() {
      Row() {
        // 节次时间列
        Column() {
          Text('节次/时间')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .height(GRID_HEADER_HEIGHT)
            .textAlign(TextAlign.Center)
          ForEach(this.sectionTimes, (t: SectionTime, i: number) => {
            Column() {
              Text((i + 1).toString())
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Text(t.start + ' - ' + t.end)
                .fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .height(GRID_ROW_HEIGHT)
            .justifyContent(FlexAlign.Center)
          }, (t: SectionTime, i: number) => {
            return 'sec' + i.toString();
          })
        }
        .width(GRID_SECTION_COL_WIDTH)

        // 周一 ~ 周日
        ForEach(WEEK_DAY_NAMES, (dayName: string, idx: number) => {
          Column() {
            Text(dayName + (this.isToday(idx + 1) ? ' · 今' : ''))
              .fontSize(14)
              .fontWeight(this.isToday(idx + 1) ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.isToday(idx + 1) ? $r('app.color.accent') : $r('app.color.text_primary'))
              .width('100%')
              .height(GRID_HEADER_HEIGHT)
              .textAlign(TextAlign.Center)

            Stack({ alignContent: Alignment.TopStart }) {
              // 背景横线
              Column() {
                ForEach(this.sectionTimes, (t: SectionTime, i: number) => {
                  Row()
                    .width('100%')
                    .height(GRID_ROW_HEIGHT)
                    .borderWidth({ bottom: 0.5 })
                    .borderColor($r('app.color.divider'))
                }, (t: SectionTime, i: number) => {
                  return 'grid' + i.toString();
                })
              }
              .width('100%')

              // 今天整列高亮
              if (this.isToday(idx + 1)) {
                Column()
                  .width('100%')
                  .height(this.sectionTimes.length * GRID_ROW_HEIGHT)
                  .backgroundColor($r('app.color.today_bg'))
              }

              // 课程卡片
              ForEach(this.dayCourses(idx + 1), (c: Course) => {
                Column() {
                  CourseCard({ course: c, week: this.week, onEdit: this.onCourseClick })
                }
                .width('100%')
                .offset({ x: 0, y: (c.startSection - 1) * GRID_ROW_HEIGHT + 4 })
              }, (c: Course) => {
                const idPart = c.id !== undefined ? c.id.toString() : 'n';
                return 'c' + idPart + '_' + c.dayOfWeek.toString() + '_' +
                  c.startSection.toString() + '_' + c.endSection.toString() + '_' +
                  c.name + '_' + c.teacher + '_' + c.room + '_' +
                  c.weekType.toString() + '_' + c.startWeek.toString() + '_' +
                  c.endWeek.toString() + '_' + c.priority.toString();
              })
            }
            .width('100%')
            .layoutWeight(1)
          }
          .layoutWeight(1)
          .borderWidth({ left: idx > 0 ? 0.5 : 0 })
          .borderColor($r('app.color.divider'))
        }, (dayName: string, idx: number) => {
          return 'day' + idx.toString();
        })
      }
      .alignItems(VerticalAlign.Top)
    }
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
    .width('100%')
  }
}
