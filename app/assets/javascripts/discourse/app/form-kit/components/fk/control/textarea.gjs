import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlTextarea extends Component {
  @action
  handleInput(event) {
    this.args.field.set(event.target.value);
  }

  get style() {
    if (!this.args.props.height) {
      return;
    }

    return `height: ${htmlSafe(
      escapeExpression(this.args.props.height) + "px"
    )}`;
  }

  <template>
    <textarea
      class="form-kit__control-textarea"
      style={{this.style}}
      ...attributes
      {{on "input" this.handleInput}}
    >{{@value}}</textarea>
  </template>
}
