import Component from "@ember/component";

export default class ReviewableFieldText extends Component {}

<Input
  @value={{this.value}}
  class="reviewable-input-text"
  {{on "change" this.valueChanged}}
/>