import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import AceEditor from "discourse/components/ace-editor";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlCode extends FKBaseControl {
  static controlType = "code";

  initialValue = this.args.field.value || "";

  get style() {
    if (!this.args.height) {
      return;
    }

    return trustHTML(`height: ${escapeExpression(this.args.height)}px`);
  }

  @action
  handleInput(content) {
    this.args.field.set(content);
  }

  <template>
    <AceEditor
      aria-describedby={{@field.describedBy}}
      aria-invalid={{if @field.error "true"}}
      class="form-kit__control-code"
      id={{@field.id}}
      name={{@field.name}}
      style={{this.style}}
      ...attributes
      @content={{this.initialValue}}
      @disabled={{@field.disabled}}
      @mode={{@lang}}
      @onChange={{this.handleInput}}
      @resizable={{true}}
    />
  </template>
}
