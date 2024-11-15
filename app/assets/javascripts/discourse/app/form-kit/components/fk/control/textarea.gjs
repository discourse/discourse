import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlTextarea extends Component {
  static controlType = "textarea";

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
    <textarea
      class="form-kit__control-textarea"
      style={{this.style}}
      disabled={{@disabled}}
      ...attributes
      {{on "input" this.handleInput}}
    >{{@value}}</textarea>
  </template>
}
