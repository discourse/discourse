import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import Invitee from "./invitee";

export default class DiscoursePostEventInvitees extends Component {
  @service modal;
  @service siteSettings;

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
            <div class="event-invitees-icon" title={{this.inviteesTitle}}>
              {{icon "users"}}
              {{#if this.hasAttendees}}
                <span class="going">{{this.statsInfo}}</span>
              {{/if}}
            </div>
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
