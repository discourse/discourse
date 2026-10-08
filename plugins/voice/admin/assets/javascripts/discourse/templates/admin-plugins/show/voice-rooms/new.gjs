import VoiceRoomForm from "discourse/plugins/voice/discourse/components/voice-room-form";

export default <template>
  <VoiceRoomForm @onSave={{@controller.saveRoom}} @room={{@controller.model}} />
</template>
