import dIcon from "discourse/ui-kit/helpers/d-icon";

const LiveParticipantSidebarSuffix = <template>
  {{! Always rendered, even with no icons — this is the element that pushes
      itself and the hover menu button to the right edge of the row. }}
  <span class="live-participant-suffix">
    {{#if @suffixArgs.isHandRaised}}
      {{dIcon "hand" title="live.participant.status_hand_raised"}}
    {{/if}}
    {{#if @suffixArgs.isScreenSharing}}
      {{dIcon "display" title="live.participant.status_screen_sharing"}}
    {{/if}}
    {{#if @suffixArgs.isVideoOn}}
      {{dIcon "video" title="live.participant.status_video"}}
    {{/if}}
    {{#if @suffixArgs.isPtt}}
      {{dIcon "walkie-talkie" title="live.participant.status_ptt"}}
    {{/if}}
    {{#if @suffixArgs.isMuted}}
      {{dIcon "microphone-slash" title="live.participant.status_muted"}}
    {{/if}}
    {{#if @suffixArgs.isDeafened}}
      {{dIcon "volume-xmark" title="live.participant.status_deafened"}}
    {{/if}}
  </span>
</template>;

export default LiveParticipantSidebarSuffix;
