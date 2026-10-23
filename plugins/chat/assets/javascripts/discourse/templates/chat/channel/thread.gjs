import ChannelThread from "discourse/plugins/chat/discourse/components/chat/routes/channel-thread";

export default <template>
  <ChannelThread
    @targetMessageId={{@controller.targetMessageId}}
    @thread={{@controller.model}}
  />
</template>
