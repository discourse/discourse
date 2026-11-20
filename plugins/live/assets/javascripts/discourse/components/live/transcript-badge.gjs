import Component from "@glimmer/component";
import { service } from "@ember/service";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The transcript consent signal: a quiet pill rendered wherever a room's
// call is shown, so nobody can be transcribed without a way of noticing.
// Deliberately calmer than the recording badge — the transcript never
// leaves the recorder's browser.
export default class LiveTranscriptBadge extends Component {
  @service currentUser;
  @service liveWebrtc;

  get selfTranscribing() {
    return this.liveWebrtc.isTranscribingRoom(this.args.room.id);
  }

  get otherTranscribers() {
    return (this.args.room.active_participants || [])
      .filter(
        (participant) =>
          participant?.is_transcribing &&
          Number(participant.id) !== this.currentUser?.id
      )
      .map((participant) => participant.username);
  }

  get visible() {
    return this.selfTranscribing || this.otherTranscribers.length > 0;
  }

  get transcriberNames() {
    const names = this.otherTranscribers;
    if (this.selfTranscribing) {
      names.unshift(i18n("live.transcript.transcriber_you"));
    }
    return names;
  }

  get tooltip() {
    const names = this.transcriberNames;
    if (this.selfTranscribing && names.length === 1) {
      return i18n("live.transcript.indicator_tooltip_self");
    }
    return i18n("live.transcript.indicator_tooltip", {
      count: names.length,
      usernames: names.join(", "),
    });
  }

  // While the model is still loading/downloading there would otherwise be no
  // feedback at all when captions are off, so the badge doubles as progress.
  get label() {
    if (this.selfTranscribing && this.liveWebrtc.subtitlesLoading) {
      const percent = this.liveWebrtc.subtitlesProgress;
      return percent !== null
        ? i18n("live.subtitles.downloading", { percent })
        : i18n("live.subtitles.loading");
    }
    return i18n("live.transcript.indicator");
  }

  <template>
    {{#if this.visible}}
      <DTooltip
        class="live-transcript-badge"
        @identifier="live-transcript-badge"
        @placement="bottom"
      >
        <:trigger>
          {{dIcon "closed-captioning"}}
          <span class="live-transcript-badge__label">
            {{this.label}}
          </span>
        </:trigger>
        <:content>
          {{this.tooltip}}
        </:content>
      </DTooltip>
    {{/if}}
  </template>
}
