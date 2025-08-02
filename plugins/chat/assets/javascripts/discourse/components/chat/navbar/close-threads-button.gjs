import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatNavbarCloseThreadsButton extends Component {
  @service site;

  closeButtonTitle = i18n("chat.thread.close");

  <template>
    {{#if this.site.desktopView}}
      <LinkTo
        class="c-navbar__close-threads-button btn-transparent btn btn-icon no-text"
        @route="chat.channel"
        @models={{@channel.routeModels}}
        title={{this.closeButtonTitle}}
      >
        {{icon "xmark"}}
      </LinkTo>
    {{/if}}
  </template>
}
