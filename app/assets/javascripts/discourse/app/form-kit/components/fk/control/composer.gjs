import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DEditor from "discourse/components/d-editor";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlComposer extends Component {
  static controlType = "composer";

  @action
  handleInput(event) {
    this.args.field.set(event.target.value);
  }

  get style() {
    if (this.args.height) {
      return;
    }

    return htmlSafe(`height: ${escapeExpression(this.args.height)}px`);
  }

  <template>
    <DEditor
      @value={{readonly @value}}
      @change={{this.handleInput}}
      @disabled={{@disabled}}
      class="form-kit__control-composer"
      style={{this.style}}
      @textAreaId={{@field.id}}
    />
  </template>
}
