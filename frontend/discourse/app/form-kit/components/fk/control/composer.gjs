import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DEditor from "discourse/components/d-editor";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import concatClass from "discourse/helpers/concat-class";
import { escapeExpression } from "discourse/lib/utilities";

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

    return htmlSafe(`height: ${escapeExpression(this.args.height)}px`);
  }

  <template>
    <DEditor
      @value={{readonly @field.value}}
      @change={{this.handleInput}}
      @disabled={{@field.disabled}}
      class={{concatClass
        "form-kit__control-composer"
        (if @preview "--preview")
      }}
      style={{this.style}}
      @textAreaId={{@field.id}}
    />
  </template>
}
