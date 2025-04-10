import Component from "@ember/component";
import { classNameBindings } from "@ember-decorators/component";

@classNameBindings(":wizard-image-preview", "fieldClass")
export default class Generic extends Component {
  <template>
    <img src={{this.field.value}} class={{this.fieldClass}} />
  </template>
}
