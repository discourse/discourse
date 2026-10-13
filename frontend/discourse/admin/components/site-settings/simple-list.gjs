/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import SimpleList from "discourse/admin/components/simple-list";

@tagName("")
export default class SiteSettingSimpleList extends Component {
  inputDelimiter = "|";

  @action
  onChange(value) {
    this.set("value", value.join(this.inputDelimiter || "\n"));
  }

  <template>
    <div ...attributes>
      <SimpleList
        @allowAny={{this.setting.allow_any}}
        @choices={{this.setting.choices}}
        @inputDelimiter={{this.inputDelimiter}}
        @onChange={{this.onChange}}
        @values={{this.value}}
      />
    </div>
  </template>
}
