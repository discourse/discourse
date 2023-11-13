import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class ChatThreadListHeader extends Component {
  @service router;
  @service site;

  threadListTitle = I18n.t("chat.threads.list");
  closeButtonTitle = I18n.t("chat.thread.close");
  showCloseButton = !this.site.mobileView;

  get showBackButton() {
    return this.args.channel && this.site.mobileView;
  }

  get backButton() {
    return {
      route: "chat.channel.index",
      models: this.args.channel.routeModels,
      title: I18n.t("chat.return_to_channel"),
    };
  }

  <template>
    <div class="chat-thread-list-header">
      <div class="chat-thread-header__left-buttons">
        {{#if this.showBackButton}}
          <LinkTo
            class="chat-thread__back-to-previous-route btn-flat btn btn-icon no-text"
            @route={{this.backButton.route}}
            @models={{this.backButton.models}}
            title={{this.backButton.title}}
          >
            {{icon "chevron-left"}}
          </LinkTo>
        {{/if}}
      </div>

      <div class="chat-thread-list-header__label">
        <span>
          {{icon "discourse-threads"}}
          {{replaceEmoji this.threadListTitle}}
        </span>

        {{#if this.site.mobileView}}
          <div class="chat-thread-list-header__label-channel">
            {{replaceEmoji @channel.title}}
          </div>
        {{/if}}
      </div>

      {{#if this.showCloseButton}}
        <div class="chat-thread-header__buttons">
          <LinkTo
            class="chat-thread__close btn-flat btn btn-icon no-text"
            @route="chat.channel"
            @models={{@channel.routeModels}}
            title={{this.closeButtonTitle}}
          >
            {{icon "times"}}
          </LinkTo>
        </div>
      {{/if}}
    </div>
  </template>
}
