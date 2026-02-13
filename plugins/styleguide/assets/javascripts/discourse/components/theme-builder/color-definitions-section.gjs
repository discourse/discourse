import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";

export default class ThemeBuilderColorDefinitionsSection extends Component {
  @service themeBuilderState;

  @action
  handleChange(value) {
    this.themeBuilderState.setColorDefinitionsScss(value);
  }

  <template>
    <div class="theme-builder-color-definitions-section">
      <AceEditor
        @content={{this.themeBuilderState.colorDefinitionsScss}}
        @mode="scss"
        @onChange={{this.handleChange}}
        @editorId="theme-builder-color-definitions"
      />
    </div>
  </template>
}
