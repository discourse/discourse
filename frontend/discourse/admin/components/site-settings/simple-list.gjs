import Component from "@glimmer/component";
import { action } from "@ember/object";
import SimpleList from "discourse/admin/components/simple-list";

export default class SiteSettingSimpleList extends Component {
  inputDelimiter = "|";

  @action
  onChange(value) {
    this.args.changeValueCallback(value.join(this.inputDelimiter || "\n"));
  }

  <template>
    <div ...attributes>
      <SimpleList
        @allowAny={{@setting.allow_any}}
        @choices={{@setting.choices}}
        @inputDelimiter={{this.inputDelimiter}}
        @onChange={{this.onChange}}
        @values={{@value}}
      />
    </div>
  </template>
}
