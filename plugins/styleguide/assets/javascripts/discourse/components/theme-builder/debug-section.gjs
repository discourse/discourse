import Component from "@glimmer/component";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";
import { i18n } from "discourse-i18n";

export default class ThemeBuilderDebugSection extends Component {
  @service themeBuilderState;

  <template>
    <div class="theme-builder-debug-section">
      <h4 class="theme-builder-debug-section__heading">{{i18n
          "styleguide.theme_builder.tabs.css"
        }}</h4>
      <div class="theme-builder-css-section">
        <AceEditor
          @content={{this.themeBuilderState.composedCustomScss}}
          @mode="scss"
          @editorId="theme-builder-debug-css"
        />
      </div>

      <h4 class="theme-builder-debug-section__heading">{{i18n
          "styleguide.theme_builder.tabs.color_definitions"
        }}</h4>
      <div class="theme-builder-color-definitions-section">
        <AceEditor
          @content={{this.themeBuilderState.composedColorDefinitionsScss}}
          @mode="scss"
          @editorId="theme-builder-debug-color-definitions"
        />
      </div>
    </div>
  </template>
}
