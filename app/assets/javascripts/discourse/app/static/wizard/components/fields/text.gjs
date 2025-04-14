import Component from "@ember/component";

export default class Text extends Component {}

<Input
  id={{this.field.id}}
  @value={{this.field.value}}
  class="wizard-container__text-input"
  placeholder={{this.field.placeholder}}
  tabindex="9"
/>