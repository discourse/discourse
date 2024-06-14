import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import AceEditor from "discourse/components/ace-editor";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlCode extends Component {
  initialValue = this.args.value || "";

  @action
  handleInput(content) {
    this.args.set(content);
  }

  get style() {
    return `height: ${htmlSafe(
      escapeExpression(this.args.height ?? 200) + "px"
    )}`;
  }

  <template>
    <AceEditor
      @content={{readonly this.initialValue}}
      @mode={{@lang}}
      @disabled={{@field.disabled}}
      @onChange={{this.handleInput}}
      class="form-kit__control-code"
      style={{this.style}}
      ...attributes
    />
  </template>
}
