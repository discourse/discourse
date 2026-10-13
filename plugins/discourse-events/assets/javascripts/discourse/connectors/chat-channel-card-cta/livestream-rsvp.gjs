import DButton from "discourse/ui-kit/d-button";
import LivestreamRsvp from "../../lib/livestream-rsvp";

export default class LivestreamRsvpCard extends LivestreamRsvp {
  get showRsvpButton() {
    return this.shouldRenderRsvp && !this.channel.isFollowing;
  }

  <template>
    {{#if this.showRsvpButton}}
      <DButton
        class="btn-primary btn-small chat-channel-card__join-btn livestream-rsvp__going-button"
        @action={{this.markAsGoing}}
        @disabled={{this.isSaving}}
        @icon="check"
        @label="discourse_post_event.models.invitee.status.going"
      />
    {{else}}
      {{yield}}
    {{/if}}
  </template>
}
