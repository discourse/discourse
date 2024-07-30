import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class ChatNavbarBrowseChannelsButton extends Component {
  @service router;

  browseChannelsLabel = I18n.t("chat.channels_list_popup.browse");

  get showBrowseChannelsButton() {
    return this.router.currentRoute.name === "chat.channels";
  }

  <template>
    {{#if this.showBrowseChannelsButton}}
      <LinkTo
        @route="chat.browse"
        class="btn no-text btn-flat c-navbar__browse-button"
        title={{this.browseChannelsLabel}}
      >
        {{icon "pencil-alt"}}
      </LinkTo>
    {{/if}}
  </template>
}
