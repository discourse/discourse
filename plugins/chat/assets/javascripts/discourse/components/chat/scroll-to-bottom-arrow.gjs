import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ScrollToBottomArrow extends Component {
  @service site;

  get newMessageCount() {
    if (!this.site.mobileView) {
      return 0;
    }
    const channel = this.args.channel;
    if (!channel) {
      return 0;
    }
    return channel.tracking.unreadCount;
  }

  <template>
    <div class="chat-scroll-to-bottom">
      <DButton
        class={{dConcatClass
          "btn-flat"
          "chat-scroll-to-bottom__button"
          (if @isVisible "visible")
        }}
        @action={{@onScrollToBottom}}
      >
        <span class="chat-scroll-to-bottom__arrow">
          {{dIcon "arrow-down"}}
        </span>
        {{#if (and @isVisible this.newMessageCount)}}
          <span class="chat-scroll-to-bottom__new-messages">
            {{i18n "chat.new_messages" count=this.newMessageCount}}
          </span>
        {{/if}}
      </DButton>
    </div>
  </template>
}
