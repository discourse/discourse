import { trustHTML } from "@ember/template";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { LIVESTREAM_CHAT_CONTEXT } from "../../components/livestream/embeddable-chat-channel";
import LivestreamRsvp from "../../lib/livestream-rsvp";

export default class LivestreamRsvpPreviewCard extends LivestreamRsvp {
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
