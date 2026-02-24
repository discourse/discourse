/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import ValueList from "discourse/admin/components/value-list";

@tagName("")
export default class UrlList extends Component {
  <template>
    <div ...attributes>
      <ValueList
        @disabled={{@disabled}}
        @values={{this.value}}
        @addKey="admin.site_settings.add_url"
      />
    </div>
  </template>
}
