import { fn } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

const Member = <template>
  <DButton
    class={{dConcatClass
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
        {{dIcon "user-group"}}
      </div>
      <span class="chat-message-creator__member-group">
        {{@member.model.name}}
      </span>
    {{/if}}

    {{dIcon "xmark"}}
  </DButton>
</template>;

export default Member;
