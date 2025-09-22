/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import ValueList from "admin/components/value-list";

export default class UrlList extends Component {
  <template>
    <ValueList
      @disabled={{@disabled}}
      @values={{this.value}}
      @addKey="admin.site_settings.add_url"
    />
  </template>
}
