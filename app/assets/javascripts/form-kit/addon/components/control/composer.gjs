import Component from "@glimmer/component";
import { action } from "@ember/object";
import DEditor from "discourse/components/d-editor";

export default class FKControlComposer extends Component {
  @action
  handleInput(event) {
    this.args.set(event.target.value);
  }

  <template>
    <DEditor
      @value={{readonly @value}}
      @change={{this.handleInput}}
      @disabled={{@field.disabled}}
      class="form-kit__control-composer"
    />
  </template>
}
