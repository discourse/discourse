import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { loadZoomMeetingSdk } from "discourse/lib/load-zoom-meeting-sdk";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import DiscoursePostEvent from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event";
import DiscoursePostEventEvent from "discourse/plugins/discourse-calendar/discourse/models/discourse-post-event-event";
import fetchZoomJoinPayload from "../../lib/fetch-zoom-join-payload";
import { isWithinEventTimeframe } from "../../models/discourse-post-event-event";
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
    if (this.hasLoaded || !this.canJoinNow) {
      return;
    }

    this.hasLoaded = true;
    await this.loadZoom();
  });

  get post() {
    return this.args.topic?.postStream?.posts?.[0];
  }

  get event() {
    if (!this.post?.event) {
      return null;
    }

    return DiscoursePostEventEvent.create(this.post.event);
  }

  // The join button on the topic page is disabled outside this window, but the
  // route can be reached directly at any time, so the gate has to be applied
  // here too. The server enforces the same window when issuing a signature.
  get canJoinNow() {
    return (
      isWithinEventTimeframe(
        this.event?.allDay,
        this.event?.startsAt,
        this.event?.endsAt
      ) ||
      // TODO (martin) showzoom is for testing only, remove before merge
      new URLSearchParams(window.location.search).get("showzoom")
    );
  }

  get zoomUrl() {
    return this.event?.livestreamUrl;
  }

  get mobileLeaveUrl() {
    return getURL(
      `/t/${this.args.topic.slug}/${this.args.topic.id}/zoom?zoom_left=1`
    );
  }

  get retryZoomRoute() {
    return getURL(`/t/${this.args.topic.slug}/${this.args.topic.id}/zoom`);
  }

  get topicUrl() {
    return getURL(
      this.args.topic.url || `/t/${this.args.topic.slug}/${this.args.topic.id}`
    );
  }

  get returnedFromZoom() {
    return new URLSearchParams(window.location.search).has("zoom_left");
  }

  @action
  async loadZoom() {
    if (this.returnedFromZoom) {
      this.errorMessage = i18n("discourse_calendar.livestream.zoom.load_error");
      return;
    }

    try {
      const payload = await fetchZoomJoinPayload(this.args.topic.id);
      const ZoomMtg = await loadZoomMeetingSdk();

      ZoomMtg.preLoadWasm();
      ZoomMtg.prepareWebSDK();
      ZoomMtg.i18n.load("en-US");
      ZoomMtg.i18n.reload("en-US");

      await new Promise((resolve, reject) => {
        ZoomMtg.init({
          leaveUrl: this.mobileLeaveUrl,
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
  }

  get canOpenChat() {
    return this.args.topic?.chat_channel_id && this.siteSettings.chat_enabled;
  }

  @action
  openChat() {
    this.modal.show(MobileEmbeddableChatModal);
  }

  @action
  retryZoom() {
    window.location.assign(this.retryZoomRoute);
  }

  @action
  viewTopic(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    window.location.assign(this.topicUrl);
  }

  <template>
    <div class="discourse-calendar-livestream-zoom-page">
      {{#if this.canJoinNow}}
        {{#if this.errorMessage}}
          <div class="discourse-calendar-livestream-zoom-page__fallback">
            <p>{{this.errorMessage}}</p>

            <DButton
              @href={{this.zoomUrl}}
              @label="discourse_calendar.livestream.zoom.open_in_zoom"
              @icon="up-right-from-square"
            />

            {{#if this.returnedFromZoom}}
              <DButton
                @action={{this.retryZoom}}
                @label="discourse_calendar.livestream.zoom.join"
                @icon="video"
                class="btn-primary"
              />
            {{/if}}
          </div>
        {{/if}}

        <div
          class="discourse-calendar-livestream-zoom-page__frame"
          {{this.setupZoom}}
        ></div>
      {{else}}
        <div class="discourse-calendar-livestream-zoom-page__waiting-wrapper">
          <p class="discourse-calendar-livestream-zoom-page__waiting">
            {{i18n "discourse_calendar.livestream.zoom.too_early"}}
            <a
              href={{this.topicUrl}}
              class="raw-link"
              {{on "click" this.viewTopic}}
            >
              {{i18n "discourse_calendar.livestream.zoom.view_topic"}}
            </a>
          </p>

          <DiscoursePostEvent
            @event={{this.event}}
            @post={{this.post}}
            @hideLivestreamVideo={{true}}
          />
        </div>

      {{/if}}

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
