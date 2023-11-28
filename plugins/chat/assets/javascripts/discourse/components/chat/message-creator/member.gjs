import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

export default class Member extends Component {
  <template>
    <DButton
      class={{concatClass
        "chat-message-creator__member btn-default"
        (if @highlighted "-highlighted")
      }}
      @action={{fn @onSelect @member}}
    >
      <ChatUserAvatar
        @user={{@member.model}}
        @interactive={{false}}
        @showPresence={{false}}
      />
      <span class="chat-message-creator__member-username">
        {{@member.model.username}}
      </span>
      {{icon "times"}}
    </DButton>
  </template>
}
