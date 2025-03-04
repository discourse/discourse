import Component, { Textarea } from "@ember/component";
import { on } from "@ember/modifier";

export default class ReviewableFieldTextarea extends Component {
  <template>
    <Textarea
      @value={{this.value}}
      {{on "change" this.valueChanged}}
      class="reviewable-input-textarea"
    />
  </template>
}
