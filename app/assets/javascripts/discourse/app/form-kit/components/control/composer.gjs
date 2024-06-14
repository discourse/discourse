import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DEditor from "discourse/components/d-editor";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlComposer extends Component {
  @action
  handleInput(event) {
    this.args.set(event.target.value);
  }

  get style() {
    return `height: ${htmlSafe(
      escapeExpression(this.args.height ?? 200) + "px"
    )}`;
  }

  <template>
    <DEditor
      @value={{readonly @value}}
      @change={{this.handleInput}}
      @disabled={{@field.disabled}}
      class="form-kit__control-composer"
      style={{this.style}}
    />
  </template>
}
