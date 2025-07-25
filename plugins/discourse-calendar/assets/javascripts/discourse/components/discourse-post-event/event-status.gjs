import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class EventStatus extends Component {
  get eventStatusLabel() {
    return i18n(
      `discourse_post_event.models.event.status.${this.args.event.status}.title`
    );
  }

  get eventStatusDescription() {
    return i18n(
      `discourse_post_event.models.event.status.${this.args.event.status}.description`
    );
  }

  get statusClass() {
    return `status ${this.args.event.status}`;
  }

  <template>
    {{#if @event.isExpired}}
      <span class="status expired">
        {{i18n "discourse_post_event.models.event.expired"}}
      </span>
    {{else if @event.isClosed}}
      <span class="status closed">
        {{i18n "discourse_post_event.models.event.closed"}}
      </span>
    {{else}}
      <span class={{this.statusClass}} title={{this.eventStatusDescription}}>
        {{this.eventStatusLabel}}
      </span>
    {{/if}}
  </template>
}
