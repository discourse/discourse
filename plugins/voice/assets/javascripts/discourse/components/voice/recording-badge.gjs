import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The room-wide "this call is being recorded" indicator. Rendered wherever a
// room's call is shown (full page, floating widget) so nobody can be in a
// recorded call without seeing it.
const VoiceRecordingBadge = <template>
  {{#if @room.recording}}
    <span
      class="voice-recording-badge"
      title={{i18n
        "voice.room.recording_indicator_title"
        username=@room.recording.started_by.username
      }}
    >
      {{dIcon "record-vinyl"}}
      <span class="voice-recording-badge__label">
        {{i18n "voice.room.recording_indicator"}}
      </span>
    </span>
  {{/if}}
</template>;

export default VoiceRecordingBadge;
