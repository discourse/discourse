import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";

export default class FkControlText extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.value);
  }

  get style() {
    return `height: ${htmlSafe((this.args.height ?? 200) + "px")}`;
  }

  <template>
    <textarea
      id={{@fieldId}}
      name={{@name}}
      aria-invalid={{if @invalid "true"}}
      aria-describedby={{if @invalid @errorId}}
      class="d-form__control-text"
      style={{this.style}}
      ...attributes
      {{on "input" this.handleInput}}
    >{{@value}}</textarea>
  </template>
}
