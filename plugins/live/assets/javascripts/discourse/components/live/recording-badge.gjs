import Component from "@glimmer/component";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

// The room-wide "this call is being recorded" indicator, for server
// recordings and participants recording locally alike. Rendered wherever a
// room's call is shown (full page, floating widget) so nobody can be in a
// recorded call without seeing it.
export default class LiveRecordingBadge extends Component {
  @service currentUser;
  @service liveWebrtc;

  get selfRecording() {
    return this.liveWebrtc.isRecordingLocally(this.args.room.id);
  }

  get localRecorders() {
    return (this.args.room.active_participants || [])
      .filter(
        (participant) =>
          participant?.is_recording_locally &&
          Number(participant.id) !== this.currentUser?.id
      )
      .map((participant) => participant.username);
  }

  get visible() {
    return (
      !!this.args.room.recording ||
      this.selfRecording ||
      this.localRecorders.length > 0
    );
  }

  get title() {
    const lines = [];
    const serverRecording = this.args.room.recording;

    if (serverRecording) {
      lines.push(
        i18n("live.room.recording_indicator_title", {
          username: serverRecording.started_by.username,
        })
      );
    }
    if (this.selfRecording) {
      lines.push(i18n("live.local_recording.indicator_title_self"));
    }
    const recorders = this.localRecorders;
    if (recorders.length > 0) {
      lines.push(
        i18n("live.local_recording.indicator_title", {
          count: recorders.length,
          usernames: recorders.join(", "),
        })
      );
    }

    return lines.join("\n");
  }

  <template>
    {{#if this.visible}}
      <span class="live-recording-badge" title={{this.title}}>
        {{dIcon "record-vinyl"}}
        <span class="live-recording-badge__label">
          {{i18n "live.room.recording_indicator"}}
        </span>
      </span>
    {{/if}}
  </template>
}
