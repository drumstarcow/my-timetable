import { BusinessError } from '@kit.BasicServicesKit';
import { SectionTime } from '../common/types';
import { MAX_SECTION, timeToMinutes, todayDateString } from '../common/constants';
import { SettingsService, AppSettings } from '../services/SettingsService';
import { markDataDirty } from '../services/ImportSession';
import { Logger } from '../common/Logger';

const TAG = 'SettingsPage';

/** 分钟数 -> HH:MM */
function minutesToTime(min: number): string {
  const m = Math.max(0, Math.min(23 * 60 + 59, min));
  const h = Math.floor(m / 60);
  const mm = m % 60;
  const hh = h < 10 ? '0' + h.toString() : h.toString();
  const rest = mm < 10 ? '0' + mm.toString() : mm.toString();
  return hh + ':' + rest;
}

/** 设置页：学期开始日期 + 节次时间表 */
@Component
export struct SettingsPage {
  @Consume('navPath') navPath: NavPathStack;
  @State startDate: string = todayDateString();
  @State sectionTimes: SectionTime[] = [];

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    const s = await SettingsService.getInstance().getSettings();
    this.startDate = s.semesterStartDate;
    this.sectionTimes = s.sectionTimes;
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private async persistTimes(): Promise<void> {
    try {
      await SettingsService.getInstance().updateSectionTimes(this.sectionTimes);
      markDataDirty();
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'persistTimes failed: ' + err.message);
      this.toast('保存失败：' + err.message);
    }
  }

  private pickStartDate(): void {
    const parts = this.startDate.split('-');
    let sel = new Date();
    if (parts.length === 3) {
      const y = parseInt(parts[0], 10);
      const mo = parseInt(parts[1], 10);
      const d = parseInt(parts[2], 10);
      if (!Number.isNaN(y) && !Number.isNaN(mo) && !Number.isNaN(d)) {
        sel = new Date(y, mo - 1, d);
      }
    }
    DatePickerDialog.show({
      selected: sel,
      onDateAccept: (value: Date) => {
        const y = value.getFullYear();
        const mo = value.getMonth() + 1;
        const d = value.getDate();
        const mm = mo < 10 ? '0' + mo.toString() : mo.toString();
        const dd = d < 10 ? '0' + d.toString() : d.toString();
        this.applyStartDate(y.toString() + '-' + mm + '-' + dd);
      }
    });
  }

  private async applyStartDate(s: string): Promise<void> {
    this.startDate = s;
    try {
      const cur = await SettingsService.getInstance().getSettings();
      const updated: AppSettings = {
        semesterStartDate: s,
        sectionTimes: cur.sectionTimes
      };
      await SettingsService.getInstance().saveSettings(updated);
      markDataDirty();
    } catch (e) {
      const err = e as BusinessError;
      Logger.error(TAG, 'applyStartDate failed: ' + err.message);
      this.toast('保存失败：' + err.message);
    }
  }

  /** 修改某节时间：先选开始时间，再选结束时间 */
  private pickSectionStart(index: number): void {
    const t = this.sectionTimes[index];
    const curStart = timeToMinutes(t.start);
    const curEnd = timeToMinutes(t.end);
    TimePickerDialog.show({
      selected: new Date(2020, 0, 1, Math.floor(curStart / 60), curStart % 60),
      useMilitaryTime: true,
      onAccept: (value: TimePickerResult) => {
        const startMin = value.hour * 60 + value.minute;
        TimePickerDialog.show({
          selected: new Date(2020, 0, 1, Math.floor(curEnd / 60), curEnd % 60),
          useMilitaryTime: true,
          onAccept: (value2: TimePickerResult) => {
            let endMin = value2.hour * 60 + value2.minute;
            if (endMin <= startMin) {
              endMin = startMin + 45;
              this.toast('结束时间需晚于开始时间，已自动设为开始后 45 分钟');
            }
            const updated: SectionTime = {
              start: minutesToTime(startMin),
              end: minutesToTime(endMin)
            };
            const list = this.sectionTimes.slice();
            list[index] = updated;
            this.sectionTimes = list;
            this.persistTimes();
          }
        });
      }
    });
  }

  private addSection(): void {
    if (this.sectionTimes.length >= MAX_SECTION) {
      this.toast('最多 ' + MAX_SECTION.toString() + ' 节');
      return;
    }
    let startMin = 8 * 60;
    if (this.sectionTimes.length > 0) {
      const last = this.sectionTimes[this.sectionTimes.length - 1];
      startMin = timeToMinutes(last.end) + 10;
    }
    const t: SectionTime = { start: minutesToTime(startMin), end: minutesToTime(startMin + 45) };
    const list = this.sectionTimes.slice();
    list.push(t);
    this.sectionTimes = list;
    this.persistTimes();
  }

  private removeSection(index: number): void {
    if (this.sectionTimes.length <= 1) {
      this.toast('至少保留一节');
      return;
    }
    const list = this.sectionTimes.slice();
    list.splice(index, 1);
    this.sectionTimes = list;
    this.persistTimes();
  }

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 12 }) {
            // 学期开始日期
            Column({ space: 8 }) {
              Text('学期开始日期（第 1 周的周一）')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
              Row() {
                Text(this.startDate)
                  .fontSize(17)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                Text('修改')
                  .fontSize(13)
                  .fontColor($r('app.color.accent'))
                  .onClick(() => {
                    this.pickStartDate();
                  })
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .backgroundColor($r('app.color.card_bg'))
            .alignItems(HorizontalAlign.Start)

            // 节次时间表
            Column({ space: 12 }) {
              Row() {
                Text('节次时间表')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .layoutWeight(1)
                Text('+ 添加节次')
                  .fontSize(13)
                  .fontColor($r('app.color.accent'))
                  .onClick(() => {
                    this.addSection();
                  })
              }
              .width('100%')

              ForEach(this.sectionTimes, (t: SectionTime, i: number) => {
                Row() {
                  Text('第 ' + (i + 1).toString() + ' 节')
                    .fontSize(14)
                    .fontColor($r('app.color.text_primary'))
                    .width(70)
                  Text(t.start + ' - ' + t.end)
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                    .layoutWeight(1)
                  Text('修改')
                    .fontSize(13)
                    .fontColor($r('app.color.accent'))
                    .margin({ right: 16 })
                    .onClick(() => {
                      this.pickSectionStart(i);
                    })
                  Text('删除')
                    .fontSize(13)
                    .fontColor($r('app.color.danger'))
                    .onClick(() => {
                      this.removeSection(i);
                    })
                }
                .width('100%')
              }, (t: SectionTime, i: number) => {
                return 'sec' + i.toString() + '_' + t.start + '_' + t.end;
              })

              Text('修改节次时先选开始时间、再选结束时间。')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .backgroundColor($r('app.color.card_bg'))
            .alignItems(HorizontalAlign.Start)

            Text('学期开始日期决定"今天处于第几周"；节次时间表用于网格左侧的时间显示。')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .title('设置')
  }
}
