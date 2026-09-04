import VoiceCallButton from "../../components/voice/call-button";

const VoiceProfileCallButton = <template>
  {{#if @outletArgs.model.voice_can_call}}
    <li class="voice-call-button">
      <VoiceCallButton @user={{@outletArgs.model}} />
    </li>
  {{/if}}
</template>;

export default VoiceProfileCallButton;
