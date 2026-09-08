import VoiceCallButton from "../../components/voice/call-button";

const VoiceCardCallButton = <template>
  {{#if @outletArgs.user.voice_can_call}}
    <li class="user-card-below-message-button voice-call-button">
      <VoiceCallButton @user={{@outletArgs.user}} />
    </li>
  {{/if}}
</template>;

export default VoiceCardCallButton;
