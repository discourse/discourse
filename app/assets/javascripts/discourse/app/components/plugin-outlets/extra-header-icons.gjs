import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import Connectors from "discourse-plugins-v2/connectors/extra-header-icons";

export default class ExtraHeaderIcons extends Component {
  @service currentUser;
  @service siteSettings;

  get loginRequired() {
    return this.siteSettings.login_required;
  }

  get showIcons() {
    return !this.loginRequired || this.currentUser;
  }

  get components() {
    return Connectors.map(({ module }) => module.default);
  }

  <template>
    {{#if this.showIcons}}
      <ul class="icons d-header-icons">
        {{#each this.components as |connector|}}
          <connector />
        {{/each}}
      </ul>
    {{/if}}
  </template>
}
