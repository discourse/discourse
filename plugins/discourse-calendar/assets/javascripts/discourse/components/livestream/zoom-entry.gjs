import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import fetchZoomJoinPayload from "../../lib/fetch-zoom-join-payload";
import { loadZoomMeetingSdkEmbedded } from "../../lib/load-zoom-meeting-sdk";

export default class LivestreamZoomEntry extends Component {
  @service capabilities;
  @service currentUser;
  @service siteSettings;

  @tracked errorMessage;
  @tracked isJoining = false;
  @tracked isJoined = false;
  zoomAppRoot = null;
  zoomClient = null;

  registerZoomRoot = modifier((element) => {
    this.zoomAppRoot = element;
  });

  willDestroy() {
    super.willDestroy(...arguments);
    this.zoomClient?.leaveMeeting?.();
  }

  get shouldRender() {
    return (
      this.siteSettings.livestream_enabled &&
      this.siteSettings.livestream_zoom_enabled &&
      this.args.data.topic?.chat_channel_id
    );
  }

  get isDesktop() {
    return this.capabilities.viewport.lg;
  }

  get mobileZoomRoute() {
    return getURL(
      `/t/${this.args.data.topic.slug}/${this.args.data.topic.id}/zoom`
    );
  }

  get showFallbackLink() {
    return !!this.errorMessage || !this.currentUser;
  }

  @action
  async joinZoom() {
    if (this.isJoining || this.isJoined) {
      return;
    }

    this.errorMessage = null;
    this.isJoining = true;

    try {
      const payload = await fetchZoomJoinPayload(this.args.data.topic.id);
      const ZoomMtgEmbedded = await loadZoomMeetingSdkEmbedded();

      this.zoomClient = ZoomMtgEmbedded.createClient();

      await this.zoomClient.init({
        zoomAppRoot: this.zoomAppRoot,
        language: "en-US",
        patchJsMedia: true,
        leaveOnPageUnload: true,
      });

      await this.zoomClient.join({
        signature: payload.signature,
        sdkKey: payload.sdk_key,
        meetingNumber: payload.meeting_number,
        password: payload.password || "",
        userName: payload.user_name,
        userEmail: payload.user_email,
      });

      this.isJoined = true;
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error("Error joining Zoom meeting", err);
      this.errorMessage = i18n("discourse_calendar.livestream.zoom.load_error");
    } finally {
      this.isJoining = false;
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-calendar-livestream-zoom-entry">
        {{#if this.isDesktop}}
          <div class="discourse-calendar-livestream-zoom-entry__actions">
            {{#unless this.isJoined}}
              <DButton
                @action={{this.joinZoom}}
                @label="discourse_calendar.livestream.zoom.join"
                @icon="video"
                class="btn-primary"
                @disabled={{this.isJoining}}
              />
            {{/unless}}

            {{#if this.errorMessage}}
              <p class="discourse-calendar-livestream-zoom-entry__error">
                {{this.errorMessage}}
              </p>
            {{/if}}

            {{#if this.showFallbackLink}}
              <DButton
                @href={{@data.zoomUrl}}
                @label="discourse_calendar.livestream.zoom.open_in_zoom"
                @icon="up-right-from-square"
              />
            {{/if}}
          </div>

          <div
            class="discourse-calendar-livestream-zoom-entry__frame"
            {{this.registerZoomRoot}}
          ></div>
        {{else}}
          <DButton
            @href={{this.mobileZoomRoute}}
            @label="discourse_calendar.livestream.zoom.join"
            @icon="video"
            class="btn-primary"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
