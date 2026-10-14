/** 导入方式选择弹窗（覆盖层面板，父组件控制显隐） */
@Component
export struct ImportSourceDialog {
  onPickImage: () => void = () => {
  };
  onPickFile: () => void = () => {
  };
  onManual: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @Builder
  SourceItem(title: string, desc: string, action: () => void) {
    Row() {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Text(desc)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('›')
        .fontSize(20)
        .fontColor($r('app.color.text_secondary'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(10)
    .backgroundColor($r('app.color.page_bg'))
    .onClick(() => {
      action();
    })
  }

  build() {
    Column({ space: 14 }) {
      Text('导入课表')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      this.SourceItem('图片识别', '从图库选择课表截图，自动识别课程', () => {
        this.onPickImage();
      })
      this.SourceItem('文件导入', '选择 CSV 或 Excel(xlsx) 课表文件', () => {
        this.onPickFile();
      })
      this.SourceItem('手动添加', '逐门添加课程', () => {
        this.onManual();
      })

      Button('取消')
        .width('100%')
        .backgroundColor($r('app.color.divider'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => {
          this.onClose();
        })
    }
    .padding(24)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(16)
    .width(400)
  }
}
