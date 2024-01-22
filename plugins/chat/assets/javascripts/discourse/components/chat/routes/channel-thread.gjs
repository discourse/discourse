import { array } from "@ember/helper";
import ThreadHeader from "discourse/plugins/chat/discourse/components/chat/thread/header";
import Thread from "discourse/plugins/chat/discourse/components/chat-thread";

const ChatRoutesChannelThread = <template>
  <div class="c-routes-channel-thread">
    {{#each (array @thread) as |thread|}}
      <ThreadHeader @thread={{thread}} />

      <Thread
        @thread={{thread}}
        @targetMessageId={{@targetMessageId}}
        @includeHeader={{true}}
      />
    {{/each}}
  </div>
</template>;

export default ChatRoutesChannelThread;
