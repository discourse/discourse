import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import AceEditor from "discourse/components/ace-editor";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlCode extends FKBaseControl {
  static controlType = "code";

  initialValue = this.args.field.value || "";

  @action
  handleInput(content) {
    this.args.field.set(content);
  }

  get style() {
    if (!this.args.height) {
      return;
    }

    return htmlSafe(`height: ${escapeExpression(this.args.height)}px`);
  }

  <template>
    <AceEditor
      @content={{this.initialValue}}
      @onChange={{this.handleInput}}
      @mode={{@lang}}
      @disabled={{@field.disabled}}
      @resizable={{true}}
      class="form-kit__control-code"
      style={{this.style}}
      id={{@field.id}}
      name={{@field.name}}
      aria-invalid={{if @field.error "true"}}
      aria-describedby={{if @field.error @field.errorId}}
      ...attributes
    />
  </template>
}
