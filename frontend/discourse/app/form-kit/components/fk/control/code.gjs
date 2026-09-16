import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import CodeEditor from "discourse/components/code-editor";
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
    <CodeEditor
      class="form-kit__control-code"
      name={{@field.name}}
      style={{this.style}}
      ...attributes
      @describedBy={{@field.describedBy}}
      @disabled={{@field.disabled}}
      @inputId={{@field.id}}
      @invalid={{@field.error}}
      @language={{@lang}}
      @onChange={{this.handleInput}}
      @resizable={{true}}
      @value={{this.initialValue}}
    />
  </template>
}
