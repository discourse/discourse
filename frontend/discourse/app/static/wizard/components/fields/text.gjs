/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class Text extends Component {
  <template>
    <div ...attributes>
      <Input
        id={{this.field.id}}
        @value={{this.field.value}}
        class="wizard-container__text-input"
        placeholder={{this.field.placeholder}}
        tabindex="9"
      />
    </div>
  </template>
}
