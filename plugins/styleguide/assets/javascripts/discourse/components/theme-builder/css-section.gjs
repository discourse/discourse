import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";

export default class ThemeBuilderCssSection extends Component {
  @service themeBuilderState;

  @action
  handleChange(value) {
    this.themeBuilderState.setCustomScss(value);
  }

  <template>
    <div class="theme-builder-css-section">
      <AceEditor
        @content={{this.themeBuilderState.customScss}}
        @mode="scss"
        @onChange={{this.handleChange}}
        @editorId="theme-builder-css"
      />
    </div>
  </template>
}
