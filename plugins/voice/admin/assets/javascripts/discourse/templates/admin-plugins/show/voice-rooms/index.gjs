import VoiceRoomList from "discourse/plugins/voice/admin/components/voice-room-list";

export default <template>
  <VoiceRoomList
    @rooms={{@controller.model.content}}
    @onDestroy={{@controller.destroyRoom}}
  />
</template>
