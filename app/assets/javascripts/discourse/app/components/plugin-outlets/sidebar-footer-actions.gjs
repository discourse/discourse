import Component from "@glimmer/component";
import Connectors from "discourse-plugins-v2/connectors/sidebar-footer-actions";

export default class SidebarFooterActions extends Component {
  get components() {
    return Connectors.map(({ module }) => module.default);
  }

  <template>
    {{#each this.components as |connector|}}
      <connector />
    {{/each}}
  </template>
}
