import ChannelMembers from "discourse/plugins/chat/discourse/components/chat/routes/channel-members";

export default <template>
  <ChannelMembers @channel={{@controller.model}} />
</template>
