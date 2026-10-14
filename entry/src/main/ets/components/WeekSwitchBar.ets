/** 周次切换条：上一周 / 下一周 / 回到本周 */
@Component
export struct WeekSwitchBar {
  @Prop week: number = 1;
  @Prop currentWeek: number = 1;
  onWeekChange: (w: number) => void = (w: number) => {
  };

  build() {
    Row({ space: 12 }) {
      Text('‹')
        .fontSize(22)
        .fontColor($r('app.color.text_primary'))
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_bg'))
        .onClick(() => {
          if (this.week > 1) {
            this.onWeekChange(this.week - 1);
          }
        })

      Column() {
        Text('第 ' + this.week.toString() + ' 周')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        if (this.week === this.currentWeek) {
          Text('本周')
            .fontSize(12)
            .fontColor($r('app.color.accent'))
        }
      }
      .alignItems(HorizontalAlign.Center)

      Text('›')
        .fontSize(22)
        .fontColor($r('app.color.text_primary'))
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .borderRadius(18)
        .backgroundColor($r('app.color.card_bg'))
        .onClick(() => {
          if (this.week < 25) {
            this.onWeekChange(this.week + 1);
          }
        })

      if (this.week !== this.currentWeek) {
        Text('回到本周')
          .fontSize(13)
          .fontColor($r('app.color.accent'))
          .onClick(() => {
            this.onWeekChange(this.currentWeek);
          })
      }
    }
    .justifyContent(FlexAlign.Center)
  }
}
