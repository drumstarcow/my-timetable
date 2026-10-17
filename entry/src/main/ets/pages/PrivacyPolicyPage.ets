import { PolicySection, getPrivacySections } from '../common/PrivacyText';

/** 隐私政策页：设置页入口进入，应用内离线展示完整协议 */
@Component
export struct PrivacyPolicyPage {
  @Consume('navPath') navPath: NavPathStack;

  private sections: PolicySection[] = getPrivacySections();

  build() {
    NavDestination() {
      Column() {
        Scroll() {
          Column({ space: 14 }) {
            Text('更新日期：2026 年 10 月 15 日')
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')

            Text('欢迎使用"杉课"App（软件包名：com.bravecow.timetable）。开发者深知个人信息对您的重要性，将按照法律法规要求采取相应安全保护措施，尽力保护您的个人信息安全可控。')
              .fontSize(14)
              .lineHeight(22)
              .fontColor($r('app.color.text_secondary'))
              .width('100%')

            // 核心承诺高亮块
            Text('核心承诺：本应用是一款纯本地工具应用。我们不收集、不存储、不上传您的任何个人信息，应用不需要联网即可使用全部功能，也不申请任何系统权限。')
              .fontSize(14)
              .lineHeight(22)
              .fontColor($r('app.color.text_primary'))
              .padding(12)
              .borderRadius(8)
              .backgroundColor($r('app.color.today_bg'))
              .width('100%')

            ForEach(this.sections, (s: PolicySection) => {
              Column({ space: 6 }) {
                Text(s.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                ForEach(s.lines, (line: string) => {
                  Text(line)
                    .fontSize(14)
                    .lineHeight(22)
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
          .padding(16)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('100%')
    }
    .title('隐私政策')
  }
}
