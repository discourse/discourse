import { fn } from "@ember/helper";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

const Member = <template>
  <DButton
    class={{concatClass
      "chat-message-creator__member btn-default"
      (if @highlighted "-highlighted")
    }}
    @action={{fn @onSelect @member}}
  >
    {{#if (eq @member.type "user")}}
      <ChatUserAvatar
        @user={{@member.model}}
        @interactive={{false}}
        @showPresence={{false}}
      />
      <span class="chat-message-creator__member-username">
        {{@member.model.username}}
      </span>
    {{else if (eq @member.type "group")}}
      <div class="chat-message-creator__group-icon">
        {{icon "user-group"}}
      </div>
      <span class="chat-message-creator__member-group">
        {{@member.model.name}}
      </span>
    {{/if}}

    {{icon "xmark"}}
  </DButton>
</template>;

export default Member;
