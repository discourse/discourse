import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatNavbarBrowseChannelsButton extends Component {
  @service router;

  browseChannelsLabel = i18n("chat.channels_list_popup.browse");

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
        {{icon "pencil"}}
      </LinkTo>
    {{/if}}
  </template>
}
