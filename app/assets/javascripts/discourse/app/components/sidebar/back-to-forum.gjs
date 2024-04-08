import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";
import { defaultHomepage } from "discourse/lib/utilities";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

export default class BackToForum extends Component {
  @service sidebarState;

  get shouldDisplay() {
    return this.sidebarState.isCurrentPanel(ADMIN_PANEL);
  }

  get homepage() {
    return `discovery.${defaultHomepage()}`;
  }

  <template>
    {{#if this.shouldDisplay}}
      <LinkTo @route={{this.homepage}} class="sidebar-sections__back-to-forum">
        {{dIcon "arrow-left"}}

        <span>{{i18n "admin.back_to_forum"}}</span>
      </LinkTo>
    {{/if}}
  </template>
}
