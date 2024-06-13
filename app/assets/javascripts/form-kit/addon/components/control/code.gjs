import Component from "@glimmer/component";
import { action } from "@ember/object";
import AceEditor from "discourse/components/ace-editor";

export default class FKControlCode extends Component {
  initialValue = this.args.value || "";

  @action
  handleInput(content) {
    this.args.setValue(content);
  }

  <template>
    <AceEditor
      @content={{readonly this.initialValue}}
      @mode={{@lang}}
      @disabled={{@field.disabled}}
      @onChange={{this.handleInput}}
      class="form-kit__control-code"
    />
  </template>
}
