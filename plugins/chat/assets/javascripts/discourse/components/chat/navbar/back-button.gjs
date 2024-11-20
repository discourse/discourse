import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatNavbarBackButton extends Component {
  @service chatStateManager;

  get icon() {
    return this.args.icon ?? "chevron-left";
  }

  get title() {
    return this.args.title ?? i18n("chat.browse.back");
  }

  get targetRoute() {
    return this.args.route ?? "chat";
  }

  <template>
    {{#if this.chatStateManager.isDrawerExpanded}}
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
    {{/if}}
  </template>
}
