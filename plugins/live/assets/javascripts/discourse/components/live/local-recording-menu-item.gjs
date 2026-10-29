import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import {
  localRecordingSupported,
  requestTabCapture,
} from "../../lib/live/local-recorder.js";

// A room menu entry for recording the call to this device. Tries a tab
// capture for video and offers audio only when that isn't possible.
export default class LiveLocalRecordingMenuItem extends Component {
  @service currentUser;
  @service dialog;
  @service liveWebrtc;
  @service siteSettings;

  // One record entry per user: where the server can record the call, that
  // takes precedence.
  get available() {
    return (
      this.currentUser?.live_can_record_locally &&
      localRecordingSupported() &&
      this.liveWebrtc.isActiveRoom(this.args.room.id) &&
      !this.#serverRecordingAvailable
    );
  }

  get active() {
    return this.liveWebrtc.isRecordingLocally(this.args.room.id);
  }

  get disabled() {
    return !this.active && this.liveWebrtc.localRecordingBusy;
  }

  get label() {
    return this.active
      ? i18n("live.local_recording.stop")
      : i18n("live.local_recording.start");
  }

  get #serverRecordingAvailable() {
    return (
      this.args.room.can_manage &&
      this.siteSettings.live_livekit_recording_enabled &&
      this.liveWebrtc.isLivekitRoom(this.args.room.id)
    );
  }

  // Bound with {{on "click"}}, not DButton's @action: that defers via next(),
  // and Firefox only allows getDisplayMedia during the click dispatch itself.
  @action
  toggle() {
    const roomId = this.args.room.id;

    if (this.active) {
      this.args.closeMenu?.();
      this.liveWebrtc.stopLocalRecording();
      return;
    }

    if (!this.liveWebrtc.screenShareSupported) {
      this.args.closeMenu?.();
      this.liveWebrtc.startLocalRecording(roomId);
      return;
    }

    // Closing the menu destroys this component before the capture settles.
    const { dialog, liveWebrtc } = this;
    requestTabCapture().then(
      (displayStream) => liveWebrtc.startLocalRecording(roomId, displayStream),
      () => {
        // Declining the picker is as likely as a failure, so ask rather than
        // silently fall back.
        if (liveWebrtc.isActiveRoom(roomId)) {
          dialog.yesNoConfirm({
            message: i18n("live.local_recording.audio_only_confirm"),
            didConfirm: () => liveWebrtc.startLocalRecording(roomId),
          });
        }
      }
    );
    this.args.closeMenu?.();
  }

  <template>
    {{#if this.available}}
      <@item>
        <DButton
          class={{dConcatClass
            "btn-transparent live-local-recording-toggle"
            (if this.active "--recording")
          }}
          @disabled={{this.disabled}}
          @icon={{if this.active "stop" "record-vinyl"}}
          @translatedLabel={{this.label}}
          {{on "click" this.toggle}}
        />
      </@item>
    {{/if}}
  </template>
}
