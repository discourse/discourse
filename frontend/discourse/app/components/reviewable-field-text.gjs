/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class ReviewableFieldText extends Component {
  <template>
    <Input
      @value={{this.value}}
      class="reviewable-input-text"
      {{on "change" this.valueChanged}}
    />
  </template>
}
