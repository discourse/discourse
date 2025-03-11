import Component from "@ember/component";

export default class ReviewableFieldEditor extends Component {}
<DEditor @value={{this.value}} @change={{this.valueChanged}} />