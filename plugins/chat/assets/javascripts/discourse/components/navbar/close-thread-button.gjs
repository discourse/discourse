import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import I18n from "I18n";

export default class ChatNavbarCloseThreadButton extends Component {
  @service site;

  closeThreadTitle = I18n.t("chat.thread.close");

  <template>
    {{#if this.site.desktopView}}
      <LinkTo
        class="c-navbar__close-thread-button btn-flat btn btn-icon no-text"
        @route="chat.channel"
        @models={{@thread.channel.routeModels}}
        title={{this.closeThreadTitle}}
      >
        {{icon "times"}}
      </LinkTo>
    {{/if}}
  </template>
}
