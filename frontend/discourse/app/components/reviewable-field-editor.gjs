/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DEditor from "discourse/ui-kit/d-editor";

@tagName("")
export default class ReviewableFieldEditor extends Component {
  <template>
    <DEditor @value={{this.value}} @change={{this.valueChanged}} />
  </template>
}
