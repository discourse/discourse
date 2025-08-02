import Component from "@ember/component";
import DEditor from "discourse/components/d-editor";

export default class ReviewableFieldEditor extends Component {
  <template>
    <DEditor @value={{this.value}} @change={{this.valueChanged}} />
  </template>
}
