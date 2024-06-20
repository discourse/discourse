import Component from "@glimmer/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import DEditor from "discourse/components/d-editor";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlComposer extends Component {
  @action
  handleInput(event) {
    this.args.field.set(event.target.value);
  }

  get style() {
    if (this.args.props.height) {
      return;
    }

    return `height: ${htmlSafe(
      escapeExpression(this.args.props.height) + "px"
    )}`;
  }

  <template>
    <DEditor
      @value={{readonly @value}}
      @change={{this.handleInput}}
      @disabled={{@field.disabled}}
      class="form-kit__control-composer"
      style={{this.style}}
      @textAreaId={{@field.id}}
    />
  </template>
}
