import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { lock, unlock } from "discourse/lib/body-scroll-lock";
import ChatScrollableList from "../modifiers/chat/scrollable-list";

export default class ChatMessagesScroller extends Component {
  @action
  lockBody(element) {
    lock(element, { reverseColumn: true });
  }

  @action
  unlockBody(element) {
    unlock(element);
  }

  <template>
    <div
      class="chat-messages-scroller popper-viewport"
      {{didInsert @onRegisterScroller}}
      {{didInsert this.lockBody}}
      {{willDestroy this.unlockBody}}
      {{ChatScrollableList
        (hash onScroll=@onScroll onScrollEnd=@onScrollEnd reverse=true)
      }}
    >
      {{yield}}
    </div>
  </template>
}
