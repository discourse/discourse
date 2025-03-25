import Component from "@ember/component";

export default class List extends Component {}

<ValueList
  @values={{this.value}}
  @inputDelimiter="|"
  @choices={{this.setting.choices}}
/>