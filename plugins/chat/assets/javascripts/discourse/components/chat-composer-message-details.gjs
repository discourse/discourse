import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import ChatUserAvatar from "./chat-user-avatar";

const ChatComposerMessageDetails = <template>
  <div
    class="chat-composer-message-details"
    data-id={{@message.id}}
    data-action={{if @message.editing "edit" "reply"}}
  >
    <div class="chat-reply">
      {{dIcon (if @message.editing "pencil" "reply")}}
      <ChatUserAvatar @user={{@message.user}} />
      <span class="chat-reply__username">{{@message.user.username}}</span>
      <span class="chat-reply__excerpt">
        {{dReplaceEmoji (trustHTML @message.excerpt)}}
      </span>
    </div>

    <DButton
      @action={{@cancelAction}}
      @icon="circle-xmark"
      @title="cancel"
      class="btn-flat cancel-message-action"
    />
  </div>
</template>;

export default ChatComposerMessageDetails;
