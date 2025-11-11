import ChannelThread from "discourse/plugins/chat/discourse/components/chat/routes/channel-thread";

export default <template>
  <ChannelThread
    @thread={{@controller.model}}
    @targetMessageId={{@controller.targetMessageId}}
  />
</template>
