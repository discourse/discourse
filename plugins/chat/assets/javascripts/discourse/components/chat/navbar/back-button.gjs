import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import icon from "discourse-common/helpers/d-icon";
import I18n from "I18n";
import { FOOTER_NAV_ROUTES } from "discourse/plugins/chat/discourse/lib/chat-constants";

export default class ChatNavbarBackButton extends Component {
  get icon() {
    return this.args.icon ?? "chevron-left";
  }

  get title() {
    return this.args.title ?? I18n.t("chat.browse.back");
  }

  get targetRoute() {
    if (FOOTER_NAV_ROUTES.includes(this.args.route)) {
      return this.args.route;
    } else {
      return "chat";
    }
  }

  <template>
    {{#if @routeModels}}
      <LinkTo
        @route={{@route}}
        @models={{@routeModels}}
        class="c-navbar__back-button no-text btn-transparent btn"
        title={{this.title}}
      >
        {{#if (has-block)}}
          {{yield}}
        {{else}}
          {{icon this.icon}}
        {{/if}}
      </LinkTo>
    {{else}}
      <LinkTo
        @route={{this.targetRoute}}
        class="c-navbar__back-button no-text btn-transparent btn"
        title={{this.title}}
      >
        {{#if (has-block)}}
          {{yield}}
        {{else}}
          {{icon this.icon}}
        {{/if}}
      </LinkTo>
    {{/if}}
  </template>
}
