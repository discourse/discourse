import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// A grid tile for someone who is being rung but hasn't picked up: styled
// apart from real participant tiles so nobody mistakes them for present.
const VoiceRingingTile = <template>
  <div class="voice-video-tile voice-ringing-tile" ...attributes>
    <div class="voice-ringing-tile__animation">
      {{! Placeholder — a bespoke ringing SVG animation will replace this icon }}
      {{dIcon "phone-volume"}}
    </div>
    <div class="voice-video-tile__info">
      <span class="voice-video-tile__name">
        {{i18n "voice.call.calling" username=@user.username}}
      </span>
    </div>
  </div>
</template>;

export default VoiceRingingTile;
