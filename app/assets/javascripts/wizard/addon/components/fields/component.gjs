import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { dasherize } from "@ember/string";
import components from "./components";

export default class ComponentField extends Component {
  get component() {
    let id = dasherize(this.args.field.id);
    assert(`"${id}" is not a valid wizard component`, id in components);
    return components[id];
  }

  <template>
    <this.component
      @wizard={{@wizard}}
      @step={{@step}}
      @field={{@field}}
      @fieldClass={{this.fieldClass}}
    />
  </template>
}
