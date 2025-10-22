import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import PostEventInvitees from "../modal/post-event-invitees";
import Invitee from "./invitee";

export default class DiscoursePostEventInvitees extends Component {
  @service modal;

  @action
  showInvitees() {
    this.modal.show(PostEventInvitees, {
      model: {
        event: this.args.event,
        title: this.args.event.title,
        extraClass: this.args.event.extraClass,
      },
    });
  }

  get hasAttendees() {
    return this.args.event.stats.going > 0;
  }

  get statsInfo() {
    return this.args.event.stats.going;
  }

  get inviteesTitle() {
    return i18n("discourse_post_event.models.invitee.status.going_count", {
      count: this.args.event.stats.going,
    });
  }

  <template>
    {{#unless @event.minimal}}
      {{#if @event.shouldDisplayInvitees}}
        <section class="event__section event-invitees">
          <div class="event-invitees-avatars-container">
            <DButton
              class="event-invitees-icon btn-transparent"
              title={{this.inviteesTitle}}
              @action={{this.showInvitees}}
            >
              {{icon "users"}}
              {{#if this.hasAttendees}}
                <span class="going">{{this.statsInfo}}</span>
              {{/if}}
            </DButton>
            <ul class="event-invitees-avatars">
              {{#each @event.sampleInvitees as |invitee|}}
                <Invitee @invitee={{invitee}} />
              {{/each}}
            </ul>
          </div>
        </section>
      {{else}}
        {{#unless @event.isStandalone}}
          <section class="event__section event-invitees no-rsvp">
            <p class="no-rsvp-description">{{i18n
                "discourse_post_event.models.invitee.status.going_count.other"
                count="0"
              }}</p>
          </section>
        {{/unless}}
      {{/if}}
    {{/unless}}
  </template>
}
