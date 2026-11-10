/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class Text extends Component {
  <template>
    <div ...attributes>
      <Input
        class="wizard-container__text-input"
        id={{this.field.id}}
        placeholder={{this.field.placeholder}}
        tabindex="9"
        @value={{this.field.value}}
      />
    </div>
  </template>
}
