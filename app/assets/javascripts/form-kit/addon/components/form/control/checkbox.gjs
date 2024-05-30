import Component from "@glimmer/component";
import { on } from "@ember/modifier";

export default class FormControlCheckbox extends Component {
  <template>
    <input ...attributes type="checkbox" {{on "click" @onChange}} />
  </template>
}
