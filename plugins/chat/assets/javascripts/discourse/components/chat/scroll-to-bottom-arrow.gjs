import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { and } from "discourse/truth-helpers";
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
        class={{concatClass
          "btn-flat"
          "chat-scroll-to-bottom__button"
          (if @isVisible "visible")
        }}
        @action={{@onScrollToBottom}}
      >
        <span class="chat-scroll-to-bottom__arrow">
          {{icon "arrow-down"}}
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
