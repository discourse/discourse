import Component from "@ember/component";

export default class ReviewableFieldTextarea extends Component {}

<Textarea
  @value={{this.value}}
  {{on "change" this.valueChanged}}
  class="reviewable-input-textarea"
/>