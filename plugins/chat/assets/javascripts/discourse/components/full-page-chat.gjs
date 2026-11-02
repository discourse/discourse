import { array } from "@ember/helper";
import ChatChannel from "./chat-channel.gjs";

const FullPageChat = <template>
  {{#each (array @channel) as |channel|}}
    <ChatChannel
      @channel={{channel}}
      @isFiltering={{@isFiltering}}
      @onToggleFilter={{@onToggleFilter}}
      @targetMessageId={{@targetMessageId}}
    >
      <:aboveMessages>{{yield to="aboveMessages"}}</:aboveMessages>
    </ChatChannel>
  {{/each}}
</template>;

export default FullPageChat;
