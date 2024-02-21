import Component from "@glimmer/component";
import { Input } from "@ember/component";

export default class SchemaThemeSettingField extends Component {
  #bufferVal;

  get component() {
    if (this.args.type === "string") {
      return Input;
    }
  }

  get value() {
    return this.#bufferVal || this.args.value;
  }

  set value(v) {
    this.#bufferVal = v;
    this.args.onValueChange(v);
  }

  <template>
    <div class="schema-field" data-name={{@name}}>
      <label>{{@name}}</label>
      <div class="input">
        <this.component @value={{this.value}} />
      </div>
    </div>
  </template>
}
