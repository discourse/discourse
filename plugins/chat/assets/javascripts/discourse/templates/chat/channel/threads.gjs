import ChannelThreads from "discourse/plugins/chat/discourse/components/chat/routes/channel-threads";

export default <template>
  <ChannelThreads @channel={{@controller.model}} />
</template>
