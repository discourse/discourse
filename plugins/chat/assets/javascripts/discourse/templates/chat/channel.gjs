import Channel from "discourse/plugins/chat/discourse/components/chat/routes/channel";

export default <template>
  <Channel
    @channel={{@controller.model}}
    @targetMessageId={{@controller.targetMessageId}}
  />
</template>
