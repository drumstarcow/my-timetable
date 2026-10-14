import { SchedulePage } from './SchedulePage';
import { ImportPreviewPage } from './ImportPreviewPage';
import { SettingsPage } from './SettingsPage';

@Entry
@Component
struct Index {
  @Provide('navPath') navPath: NavPathStack = new NavPathStack();

  @Builder
  PageMap(name: string) {
    if (name === 'importPreview') {
      ImportPreviewPage()
    } else if (name === 'settings') {
      SettingsPage()
    }
  }

  build() {
    Navigation(this.navPath) {
      SchedulePage()
    }
    .navDestination(this.PageMap)
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
  }
}
