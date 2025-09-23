/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import ValueList from "admin/components/value-list";

export default class SiteSettingValueList extends Component {
  <template>
    <ValueList @disabled={{@disabled}} @values={{this.value}} />
  </template>
}
