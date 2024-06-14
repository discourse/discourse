import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

export default class FKControlText extends Component {
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
    <textarea
      class="form-kit__control-text"
      style={{this.style}}
      ...attributes
      {{on "input" this.handleInput}}
    >{{@value}}</textarea>
  </template>
}
