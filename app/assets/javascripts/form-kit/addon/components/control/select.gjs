import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import FKControlSelectOption from "./select/option";

export default class FKControlSelect extends Component {
  @action
  handleInput(event) {
    this.args.setValue(event.target.value);
  }

  <template>
    <select
      name={{@name}}
      value={{@value}}
      id={{@fieldId}}
      aria-invalid={{if @invalid "true"}}
      aria-describedby={{if @invalid @errorId}}
      disabled={{@disabled}}
      ...attributes
      class="d-form__control-select"
      {{on "input" this.handleInput}}
    >
      {{yield (hash Option=(component FKControlSelectOption selected=@value))}}
    </select>
  </template>
}
