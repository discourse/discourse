import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import bodyClass from "discourse/helpers/body-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import DiscoursePostEvent from "discourse/plugins/discourse-events/discourse/components/discourse-post-event";
import DiscoursePostEventEvent from "discourse/plugins/discourse-events/discourse/models/discourse-post-event-event";
import zoomFrameUrl from "../../lib/zoom-frame-url";
import { isWithinEventTimeframe } from "../../models/discourse-post-event-event";
import dismissKeyboardOnChatSend from "../../modifiers/dismiss-keyboard-on-chat-send";
import zoomPageViewportFit from "../../modifiers/zoom-page-viewport-fit";
import EmbeddableChatChannel from "./embeddable-chat-channel";

const FRAME_MESSAGE_SOURCE = "discourse-zoom-frame";

export default class LivestreamZoomPage extends Component {
  @service appEvents;
  @service currentUser;
  @service discoursePostEventApi;
  @service embeddableChat;
  @service siteSettings;

  @tracked errorMessage;

  // Bumped to reload the frame, which is what a retry amounts to: the meeting
  // is set up by the page inside it, from scratch, on load.
  @tracked joinAttempt = 0;

  listenForFrame = modifier(() => {
    window.addEventListener("message", this.onFrameMessage);

    return () => window.removeEventListener("message", this.onFrameMessage);
  });

  confirmAttendance = modifier(() => {
    if (this.#attendanceConfirmed) {
      return;
    }

    this.#attendanceConfirmed = true;
    this.markAsGoing();
  });
  #attendanceConfirmed = false;

  // Attendance is what follows a user into the livestream chat channel, so
  // someone who reaches the meeting without ever answering the RSVP would sit
  // in front of a read-only chat beside it. Anyone who has already made a
  // choice, including an explicit "not going", keeps it.
  //
  // This page is the only way into the meeting, and it is addressable in its
  // own right, so it is asked for here rather than beside the button that
  // usually leads here.
  //
  // Asked once per visit: the body reads tracked state, so it would otherwise
  // run again whenever the post is invalidated, and `event` is rebuilt from the
  // raw payload on each access, so a later run cannot see the invitee the first
  // one wrote

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

  get topicUrl() {
    return getURL(
      this.args.topic.url || `/t/${this.args.topic.slug}/${this.args.topic.id}`
    );
  }

  // Zoom's meeting view sizes itself to the window it is in, so it is given one
  // of its own. Inside the frame the viewport is the frame, which leaves the
  // page free to put chat below it.
  get frameUrl() {
    return zoomFrameUrl({
      topicId: this.args.topic.id,
      attempt: this.joinAttempt,
      // TODO (martin) showzoom is for testing only, remove before merge
      ignoreTimeframe: new URLSearchParams(window.location.search).get(
        "showzoom"
      ),
    });
  }

  get canRenderChat() {
    return (
      this.siteSettings.chat_enabled &&
      this.currentUser &&
      this.embeddableChat.userCanChat &&
      this.chatChannelId
    );
  }

  get chatChannelId() {
    return this.args.topic?.chat_channel_id;
  }

  @bind
  onFrameMessage(event) {
    if (
      event.origin !== window.location.origin ||
      event.data?.source !== FRAME_MESSAGE_SOURCE
    ) {
      return;
    }

    if (event.data.state === "left") {
      // This page is only ever the meeting, so a user who leaves it has
      // nowhere to go but back to the topic the webinar belongs to.
      window.location.assign(this.topicUrl);
    } else if (event.data.state === "error") {
      this.errorMessage = i18n("discourse_events.livestream.zoom.load_error");
    }
  }

  @bind
  async markAsGoing() {
    const event = this.event;

    if (!this.canJoinNow || !event?.canUpdateAttendance) {
      return;
    }

    if (event.watchingInvitee?.status) {
      return;
    }

    const payload = { status: "going" };
    const appEventData = { status: payload.status, postId: event.id };

    try {
      if (event.watchingInvitee) {
        await this.discoursePostEventApi.updateEventAttendance(event, payload);
        this.appEvents.trigger("calendar:update-invitee-status", appEventData);
      } else {
        await this.discoursePostEventApi.joinEvent(event, payload);
        this.appEvents.trigger("calendar:create-invitee-status", appEventData);
      }
    } catch (e) {
      // Chat beside the meeting stays read-only without this, and its own RSVP
      // prompt is the way back from that, so the failure is worth saying out
      // loud rather than leaving the user to find it there.
      popupAjaxError(e);
    }
  }

  @action
  retryZoom() {
    this.errorMessage = null;
    this.joinAttempt++;
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
    {{bodyClass "discourse-calendar-livestream-zoom-full"}}
    <div
      class={{dConcatClass
        "discourse-calendar-livestream-zoom-page"
        (if this.canRenderChat "--with-chat")
      }}
      {{zoomPageViewportFit}}
      {{this.confirmAttendance}}
    >
      {{#if this.canJoinNow}}
        {{#if this.errorMessage}}
          <div class="discourse-calendar-livestream-zoom-page__fallback">
            <p>{{this.errorMessage}}</p>

            <DButton
              @href={{this.zoomUrl}}
              @icon="up-right-from-square"
              @label="discourse_events.livestream.zoom.open_in_zoom"
            />

            <DButton
              class="btn-primary"
              @action={{this.retryZoom}}
              @icon="video"
              @label="discourse_events.livestream.zoom.join"
            />
          </div>
        {{/if}}

        <iframe
          allow="camera; microphone; autoplay; display-capture; fullscreen"
          class="discourse-calendar-livestream-zoom-page__frame"
          src={{this.frameUrl}}
          title={{i18n "discourse_events.livestream.zoom.frame_title"}}
          {{this.listenForFrame}}
        ></iframe>
      {{else}}
        <div class="discourse-calendar-livestream-zoom-page__waiting-wrapper">
          <p class="discourse-calendar-livestream-zoom-page__waiting">
            {{i18n "discourse_events.livestream.zoom.too_early"}}
            <a
              class="raw-link"
              href={{this.topicUrl}}
              {{on "click" this.viewTopic}}
            >
              {{i18n "discourse_events.livestream.zoom.view_topic"}}
            </a>
          </p>

          <DiscoursePostEvent
            @event={{this.event}}
            @hideLivestreamVideo={{true}}
            @post={{this.post}}
          />
        </div>

      {{/if}}

      {{#if this.canRenderChat}}
        <div
          class="discourse-calendar-livestream-zoom-page__chat"
          {{dismissKeyboardOnChatSend}}
        >
          <EmbeddableChatChannel
            @chatChannelId={{this.chatChannelId}}
            @inline={{true}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
