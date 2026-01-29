/* eslint-disable ember/no-classic-components */
import Component, { Textarea } from "@ember/component";
import { on } from "@ember/modifier";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class ReviewableFieldTextarea extends Component {
  <template>
    <div ...attributes>
      <Textarea
        @value={{this.value}}
        {{on "change" this.valueChanged}}
        class="reviewable-input-textarea"
      />
    </div>
  </template>
}
