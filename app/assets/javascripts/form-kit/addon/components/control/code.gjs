import Component from "@glimmer/component";
import { action } from "@ember/object";
import AceEditor from "discourse/components/ace-editor";

export default class FkControlCode extends Component {
  initialValue = this.args.value || "";

  @action
  handleInput(content) {
    this.args.setValue(content);
  }

  <template>
    <AceEditor
      @content={{readonly this.initialValue}}
      @mode={{@lang}}
      @disabled={{@disabled}}
      @onChange={{this.handleInput}}
      class="d-form__control-code"
    />
  </template>
}
