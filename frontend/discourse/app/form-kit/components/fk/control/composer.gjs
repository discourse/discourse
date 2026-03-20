import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { escapeExpression } from "discourse/lib/utilities";
import DEditor from "discourse/ui-kit/d-editor";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class FKControlComposer extends FKBaseControl {
  static controlType = "composer";

  @action
  handleInput(event) {
    this.args.field.set(event.target.value);
  }

  get style() {
    if (!this.args.height) {
      return;
    }

    return trustHTML(`height: ${escapeExpression(this.args.height)}px`);
  }

  <template>
    <DEditor
      @value={{readonly @field.value}}
      @change={{this.handleInput}}
      @disabled={{@field.disabled}}
      class={{dConcatClass
        "form-kit__control-composer"
        (if @preview "--preview")
      }}
      style={{this.style}}
      @textAreaId={{@field.id}}
    />
  </template>
}
