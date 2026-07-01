import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import fetchZoomJoinPayload from "../../lib/fetch-zoom-join-payload";
import { loadZoomMeetingSdk } from "../../lib/load-zoom-meeting-sdk";
import MobileEmbeddableChatModal from "./modal/mobile-embeddable-chat-modal";

export default class LivestreamZoomPage extends Component {
  @service modal;
  @service siteSettings;

  @tracked errorMessage;

  // Plain (non-tracked) guard so the modifier can read and set it within the
  // same render without triggering a tracked-property backtracking assertion.
  // It is only used to ensure the SDK is set up once, never rendered.
  hasLoaded = false;

  setupZoom = modifier(async () => {
    if (this.hasLoaded) {
      return;
    }

    this.hasLoaded = true;

    try {
      const payload = await fetchZoomJoinPayload(this.args.topic.id);
      const ZoomMtg = await loadZoomMeetingSdk();

      ZoomMtg.preLoadWasm();
      ZoomMtg.prepareWebSDK();
      ZoomMtg.i18n.load("en-US");
      ZoomMtg.i18n.reload("en-US");

      await new Promise((resolve, reject) => {
        ZoomMtg.init({
          leaveUrl: payload.leave_url,
          patchJsMedia: true,
          disableCallOut: true,
          success: resolve,
          error: reject,
        });
      });

      await new Promise((resolve, reject) => {
        ZoomMtg.join({
          signature: payload.signature,
          sdkKey: payload.sdk_key,
          meetingNumber: payload.meeting_number,
          passWord: payload.password || "",
          userName: payload.user_name,
          userEmail: payload.user_email,
          success: resolve,
          error: reject,
        });
      });
    } catch {
      this.errorMessage = i18n("discourse_calendar.livestream.zoom.load_error");
    }
  });

  get canOpenChat() {
    return this.args.topic?.chat_channel_id && this.siteSettings.chat_enabled;
  }

  get zoomUrl() {
    return this.args.topic?.postStream?.posts?.[0]?.event?.url;
  }

  @action
  openChat() {
    this.modal.show(MobileEmbeddableChatModal);
  }

  <template>
    <div class="discourse-calendar-livestream-zoom-page">
      {{#if this.errorMessage}}
        <div class="discourse-calendar-livestream-zoom-page__fallback">
          <p>{{this.errorMessage}}</p>

          <DButton
            @href={{this.zoomUrl}}
            @label="discourse_calendar.livestream.zoom.open_in_zoom"
            @icon="up-right-from-square"
          />
        </div>
      {{/if}}

      <div
        class="discourse-calendar-livestream-zoom-page__frame"
        {{this.setupZoom}}
      ></div>

      {{#if this.canOpenChat}}
        <DButton
          class="discourse-calendar-livestream-zoom-page__chat-button btn-primary"
          @action={{this.openChat}}
          @label="discourse_calendar.livestream.zoom.chat"
          @icon="comments"
        />
      {{/if}}
    </div>
  </template>
}
