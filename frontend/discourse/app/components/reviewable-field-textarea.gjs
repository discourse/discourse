/* eslint-disable ember/no-classic-components */
import Component, { Textarea } from "@ember/component";
import { on } from "@ember/modifier";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class ReviewableFieldTextarea extends Component {
  <template>
    <Textarea
      class="reviewable-input-textarea"
      @value={{this.value}}
      {{on "change" this.valueChanged}}
    />
  </template>
}
