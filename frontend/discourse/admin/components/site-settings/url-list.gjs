import Component from "@glimmer/component";
import { action } from "@ember/object";
import ValueList from "discourse/admin/components/value-list";

export default class UrlList extends Component {
  @action
  onChange(values) {
    this.args.changeValueCallback(values.join("\n"));
  }

  <template>
    <div ...attributes>
      <ValueList
        @addKey="admin.site_settings.add_url"
        @disabled={{@disabled}}
        @onChange={{this.onChange}}
        @values={{@value}}
      />
    </div>
  </template>
}
