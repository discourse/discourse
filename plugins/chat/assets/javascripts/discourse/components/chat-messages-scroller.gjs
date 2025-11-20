import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import { lock, unlock } from "discourse/lib/body-scroll-lock";
import ChatScrollableList from "../modifiers/chat/scrollable-list";

export default class ChatMessagesScroller extends Component {
  @service capabilities;

  setupLock = modifierFn((element) => {
    if (!this.capabilities.isIOS || this.capabilities.isIpadOS) {
      return;
    }

    // scroller is using flex-direction: column-reverse
    lock(element, { reverseColumn: true });

    return () => {
      unlock(element);
    };
  });

  <template>
    <div
      class="chat-messages-scroller popper-viewport"
      {{didInsert @onRegisterScroller}}
      {{this.setupLock}}
      {{ChatScrollableList
        (hash onScroll=@onScroll onScrollEnd=@onScrollEnd reverse=true)
      }}
    >
      {{yield}}
    </div>
  </template>
}
