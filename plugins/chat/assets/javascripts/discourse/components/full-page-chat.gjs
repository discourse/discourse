import { array } from "@ember/helper";
import ChatChannel from "./chat-channel";

const FullPageChat = <template>
  {{#each (array @channel) as |channel|}}
    <ChatChannel @channel={{channel}} @targetMessageId={{@targetMessageId}} />
  {{/each}}
</template>;

export default FullPageChat;
