import Component from "@ember/component";
import { action } from "@ember/object";
import SimpleList from "admin/components/simple-list";

export default class SiteSettingSimpleList extends Component {
  inputDelimiter = "|";

  @action
  onChange(value) {
    this.set("value", value.join(this.inputDelimiter || "\n"));
  }

  <template>
    <SimpleList
      @values={{this.value}}
      @inputDelimiter={{this.inputDelimiter}}
      @onChange={{this.onChange}}
      @choices={{this.setting.choices}}
      @allowAny={{this.setting.allow_any}}
    />
  </template>
}
