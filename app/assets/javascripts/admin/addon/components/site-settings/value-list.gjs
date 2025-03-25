import Component from "@ember/component";
import ValueList from "admin/components/value-list";

export default class SiteSettingValueList extends Component {
  <template><ValueList @values={{this.value}} /></template>
}
