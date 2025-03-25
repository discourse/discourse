import Component from "@ember/component";
import ValueList from "admin/components/value-list";

export default class List extends Component {
  <template>
    <ValueList
      @values={{this.value}}
      @inputDelimiter="|"
      @choices={{this.setting.choices}}
    />
  </template>
}
