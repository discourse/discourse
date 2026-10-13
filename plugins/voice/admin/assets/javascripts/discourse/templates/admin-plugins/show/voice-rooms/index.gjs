import VoiceRoomList from "discourse/plugins/voice/admin/components/voice-room-list";

export default <template>
  <VoiceRoomList
    @onDestroy={{@controller.destroyRoom}}
    @rooms={{@controller.model.content}}
  />
</template>
