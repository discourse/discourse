import VoiceRoomForm from "discourse/plugins/voice/discourse/components/voice-room-form";

export default <template>
  <VoiceRoomForm @room={{@controller.model}} @onSave={{@controller.saveRoom}} />
</template>
