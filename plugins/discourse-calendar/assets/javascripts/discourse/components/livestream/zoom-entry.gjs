import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { bind } from "discourse/lib/decorators";
import { iconHTML } from "discourse/lib/icon-library";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ZoomMeetingSession from "../../lib/zoom-meeting-session";
import zoomComponentViewLayout from "../../modifiers/zoom-component-view-layout";

export default class LivestreamZoomEntry extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service discoursePostEventApi;
  @service messageBus;
  @service siteSettings;

  @tracked waitingForHost = false;
  @tracked hasStoppedWaiting = false;
  @tracked startAnnounced = null;

  session = new ZoomMeetingSession(getOwner(this), {
    topicId: this.topic.id,
    canJoin: () => this.canJoinNow,
    onBeforeJoinAttempt: this.markAsGoing,
    onJoined: () => this.args.onJoined?.(),
    onMeetingNotStarted: () => {
      if (!this.startIsPushed || this.hasStarted) {
        return false;
      }

      this.waitingForHost = true;
      return true;
    },
  });

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(this.liveChannel, this.onLiveStateChange);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.liveChannel, this.onLiveStateChange);
    this.session.teardown();
  }

  get isWaiting() {
    return (
      this.waitingForHost ||
      this.session.isWaitingForStart ||
      this.session.isRetryingNow
    );
  }

  get liveChannel() {
    return `/discourse-calendar/livestream/zoom/${this.topic.id}`;
  }

  // Zoom only reports that a webinar started when the site has been configured
  // to receive it. Without that we cannot tell "not started" from "nobody told
  // us", so the join is attempted and retried instead.
  get startIsPushed() {
    return this.args.event.livestreamStartIsPushed;
  }

  get hasStarted() {
    return this.startAnnounced ?? this.args.event.livestreamStarted;
  }

  @bind
  onLiveStateChange(data) {
    this.startAnnounced = data.live;

    if (!data.live || !this.waitingForHost) {
      return;
    }

    this.waitingForHost = false;
    this.session.join();
  }

  get topic() {
    return this.args.event.post.topic;
  }

  get shouldRender() {
    return (
      this.siteSettings.livestream_zoom_enabled &&
      this.args.event.livestreamChatChannelId &&
      !this.args.event.pastEventTimeframe
    );
  }

  get canJoinNow() {
    return (
      this.args.event.currentlyWithinEventTimeframe ||
      // TODO (martin) showzoom is for testing only, remove before merge
      new URLSearchParams(window.location.search).get("showzoom")
    );
  }

  get isDesktop() {
    return this.capabilities.viewport.lg;
  }

  get showFallbackLink() {
    return !isEmpty(this.session.errorMessage) || this.hasStoppedWaiting;
  }

  get showAudioHint() {
    return this.session.isJoined && !this.session.hasJoinedAudio;
  }

  get joinAudioHint() {
    return trustHTML(
      i18n("discourse_calendar.livestream.zoom.join_audio_hint", {
        icon: iconHTML("zoom-join-audio"),
      })
    );
  }

  get joinDisabled() {
    return (
      this.session.isJoining ||
      this.session.isWaitingForStart ||
      !this.canJoinNow
    );
  }

  // Attendance is what follows a user into the livestream chat channel, so
  // someone who joins the webinar without ever answering the RSVP would sit in
  // front of a read-only chat. Anyone who has already made a choice, including
  // an explicit "not going", keeps it.
  @bind
  async markAsGoing() {
    const event = this.args.event;

    if (!event.canUpdateAttendance || event.watchingInvitee?.status) {
      return;
    }

    const payload = { status: "going" };
    const appEventData = { status: payload.status, postId: event.id };

    if (event.watchingInvitee) {
      await this.discoursePostEventApi.updateEventAttendance(event, payload);
      this.appEvents.trigger("calendar:update-invitee-status", appEventData);
    } else {
      await this.discoursePostEventApi.joinEvent(event, payload);
      this.appEvents.trigger("calendar:create-invitee-status", appEventData);
    }
  }

  @action
  joinZoom() {
    if (!this.currentUser) {
      return getOwner(this)
        .lookup("route:application")
        .send("showCreateAccount");
    }

    // Joining before the host starts leaves Zoom's SDK unable to try again in
    // this page, so we've got to wait
    this.hasStoppedWaiting = false;
    this.session.resumeWaitingForStart();

    if (this.startIsPushed && !this.hasStarted) {
      this.waitingForHost = true;
      this.markAsGoing().catch((err) => {
        // eslint-disable-next-line no-console
        console.error("Error marking the user as going", err);
      });
      return;
    }

    this.session.join();
  }

  @action
  stopWaiting() {
    this.waitingForHost = false;
    this.hasStoppedWaiting = true;
    this.session.stopWaitingForStart();
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-calendar-livestream-zoom-entry">
        {{#if this.isDesktop}}
          <div class="discourse-calendar-livestream-zoom-entry__actions">
            {{#if this.isWaiting}}
              <DButton
                @action={{this.stopWaiting}}
                @label="discourse_calendar.livestream.zoom.stop_waiting"
                @icon="xmark"
                class="btn-default discourse-calendar-livestream-zoom-entry__stop-waiting"
              />
            {{else}}{{#unless this.session.isJoined}}
                <DButton
                  @action={{this.joinZoom}}
                  @label="discourse_calendar.livestream.zoom.join"
                  @icon="video"
                  class="btn-primary"
                  @disabled={{this.joinDisabled}}
                />
              {{/unless}}{{/if}}

            {{#unless this.canJoinNow}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n "discourse_calendar.livestream.zoom.too_early"}}
              </p>
            {{/unless}}

            {{#if this.waitingForHost}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n "discourse_calendar.livestream.zoom.waiting_for_host"}}
              </p>
            {{else if this.session.isWaitingForStart}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n
                  "discourse_calendar.livestream.zoom.not_started_retrying"
                  count=this.session.retryCountdown
                }}
              </p>
            {{else if this.session.isRetryingNow}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n
                  "discourse_calendar.livestream.zoom.not_started_trying_again"
                }}
              </p>
            {{/if}}

            {{#if this.session.errorMessage}}
              <p class="discourse-calendar-livestream-zoom-entry__error">
                {{this.session.errorMessage}}
              </p>
            {{/if}}

            {{#if this.showFallbackLink}}
              <DButton
                class="btn-default"
                @href={{@event.livestreamUrl}}
                @label="discourse_calendar.livestream.zoom.open_in_zoom"
                @icon="up-right-from-square"
              />
            {{/if}}
          </div>

          <div
            class={{dConcatClass
              "discourse-calendar-livestream-zoom-entry__frame"
              (if this.session.showZoomFrame "--visible")
              (if this.session.isJoined "--joined")
            }}
            {{zoomComponentViewLayout this.session this.isDesktop}}
          ></div>

          {{#if this.showAudioHint}}
            <p class="discourse-calendar-livestream-zoom-entry__audio-hint">
              {{this.joinAudioHint}}
            </p>
          {{/if}}
        {{else}}
          <div class="discourse-calendar-livestream-zoom-entry__actions">
            <DButton
              @route="topic-zoom"
              @routeModels={{array this.topic.slug this.topic.id}}
              @label="discourse_calendar.livestream.zoom.join"
              @icon="video"
              class="btn-primary"
              @disabled={{this.joinDisabled}}
            />

            {{#unless this.canJoinNow}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n "discourse_calendar.livestream.zoom.too_early"}}
              </p>
            {{/unless}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
