import ChannelPins from "discourse/plugins/chat/discourse/components/chat/routes/channel-pins";

export default <template>
  <ChannelPins
    @channel={{@model.channel}}
    @pinnedMessages={{@model.pinnedMessages}}
  />
</template>
