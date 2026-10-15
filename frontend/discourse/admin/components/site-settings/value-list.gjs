import Component from "@glimmer/component";
import { action } from "@ember/object";
import ValueList from "discourse/admin/components/value-list";

export default class SiteSettingValueList extends Component {
  @action
  onChange(values) {
    this.args.changeValueCallback(values.join("\n"));
  }

  <template>
    <div ...attributes>
      <ValueList
        @disabled={{@disabled}}
        @onChange={{this.onChange}}
        @values={{@value}}
      />
    </div>
  </template>
}
