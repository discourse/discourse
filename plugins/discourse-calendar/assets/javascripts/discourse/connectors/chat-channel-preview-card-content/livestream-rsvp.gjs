import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { LIVESTREAM_CHAT_CONTEXT } from "../../components/livestream/embeddable-chat-channel";

export default class LivestreamRsvp extends Component {
  @service appEvents;
  @service currentUser;
  @service discoursePostEventApi;
  @service messageBus;

  @tracked isSaving = false;

  constructor() {
    super(...arguments);

    if (this.livestreamTopic && this.currentUser) {
      this.messageBus.subscribe(
        this.messageBusChannel,
        this.onMembershipChange
      );
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.livestreamTopic && this.currentUser) {
      this.messageBus.unsubscribe(
        this.messageBusChannel,
        this.onMembershipChange
      );
    }
  }

  get channel() {
    return this.args.outletArgs.channel;
  }

  get livestreamTopic() {
    return this.channel?.livestreamTopic;
  }

  get messageBusChannel() {
    return `/discourse-calendar/livestream/chat-status/${this.currentUser.id}`;
  }

  get isOnTopic() {
    return this.args.outletArgs.context === LIVESTREAM_CHAT_CONTEXT;
  }

  get rsvpMessage() {
    // when the chat renders within the livestream topic, there is no point
    // linking to the topic the user is already on
    if (this.isOnTopic) {
      return i18n("discourse_calendar.livestream.chat.rsvp_to_event");
    }

    return trustHTML(
      i18n("discourse_calendar.livestream.chat.rsvp_to_event_with_link", {
        url: this.livestreamTopic.url,
      })
    );
  }

  get shouldRenderRsvp() {
    // can_update_attendance is computed server-side for the current user, so
    // users who cannot join the event (private event group permissions,
    // closed or expired events) keep the default join button instead; the
    // same applies to users who already RSVP'd going but left the channel,
    // so they always have an actionable button
    return !!(
      this.livestreamTopic?.can_update_attendance &&
      this.livestreamTopic.event_id &&
      this.livestreamTopic.watching_invitee_status !== "going"
    );
  }

  @bind
  onMembershipChange(message) {
    const membership = JSON.parse(message).user_channel_membership;

    if (membership.chat_channel_id !== this.channel.id) {
      return;
    }

    this.channel.currentUserMembership = membership;
  }

  @action
  async markAsGoing() {
    this.isSaving = true;

    try {
      const event = await this.discoursePostEventApi.event(
        this.livestreamTopic.event_id
      );
      const payload = { status: "going" };
      const data = { status: "going", postId: event.id };

      if (event.watchingInvitee) {
        await this.discoursePostEventApi.updateEventAttendance(event, payload);
        this.appEvents.trigger("calendar:update-invitee-status", data);
      } else {
        await this.discoursePostEventApi.joinEvent(event, payload);
        this.appEvents.trigger("calendar:create-invitee-status", data);
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      if (!this.isDestroying && !this.isDestroyed) {
        this.isSaving = false;
      }
    }
  }

  <template>
    {{#if this.shouldRenderRsvp}}
      <div class="chat-channel-preview-card__icon">
        {{dIcon "calendar-days"}}
      </div>

      <div class="chat-channel-preview-card__title livestream-rsvp__message">
        {{this.rsvpMessage}}
      </div>

      <div class="chat-channel-preview-card__body">
        {{i18n "discourse_calendar.livestream.chat.rsvp_body"}}
      </div>

      <div class="chat-channel-preview-card__actions">
        <DButton
          class="btn-primary livestream-rsvp__going-button"
          @icon="check"
          @label="discourse_post_event.models.invitee.status.going"
          @disabled={{this.isSaving}}
          @action={{this.markAsGoing}}
        />
      </div>
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
