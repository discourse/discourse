import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import replaceEmoji from "discourse/helpers/replace-emoji";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";

export default class ChatDrawerHeaderTitle extends Component {
  get headerTitle() {
    if (this.args.title) {
      return I18n.t(this.args.title);
    }
    return replaceEmoji(this.args.translatedTitle);
  }

  get showChannel() {
    return this.args.channelName ?? false;
  }

  get showIcon() {
    return this.args.icon ?? false;
  }

  <template>
    <span class="chat-drawer-header__title">
      <div class="chat-drawer-header__top-line">
        <div>
          {{#if showIcon}}
            {{icon this.args.icon}}
          {{/if}}

          {{this.headerTitle}}

          {{#if showChannel}}
            -
            {{this.args.channelName}}
          {{/if}}
        </div>
      </div>
    </span>
  </template>
}
