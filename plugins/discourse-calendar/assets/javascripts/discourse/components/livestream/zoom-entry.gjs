import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { bind } from "discourse/lib/decorators";
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
  @service siteSettings;

  session = new ZoomMeetingSession(getOwner(this), {
    topicId: this.topic.id,
    canJoin: () => this.canJoinNow,
    onBeforeJoinAttempt: this.markAsGoing,
  });

  willDestroy() {
    super.willDestroy(...arguments);
    this.session.teardown();
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
    return !isEmpty(this.session.errorMessage);
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

    this.session.join();
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-calendar-livestream-zoom-entry">
        {{#if this.isDesktop}}
          <div class="discourse-calendar-livestream-zoom-entry__actions">
            {{#unless this.session.isJoined}}
              <DButton
                @action={{this.joinZoom}}
                @label="discourse_calendar.livestream.zoom.join"
                @icon="video"
                class="btn-primary"
                @disabled={{this.joinDisabled}}
              />
            {{/unless}}

            {{#unless this.canJoinNow}}
              <p class="discourse-calendar-livestream-zoom-entry__waiting">
                {{i18n "discourse_calendar.livestream.zoom.too_early"}}
              </p>
            {{/unless}}

            {{#if this.session.isWaitingForStart}}
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
