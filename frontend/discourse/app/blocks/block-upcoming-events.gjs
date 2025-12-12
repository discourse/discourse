import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { block } from "discourse/blocks";
import DButton from "discourse/components/d-button";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { longDate, shortDateNoYear } from "discourse/lib/formatter";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

@block("upcoming-events")
export default class BlockUpcomingEvents extends Component {
  @tracked events = null;

  <template>
    {{#if this.events}}
      <div class="block-upcoming-events__layout">
        <h2 class="block-upcoming-events__title">{{this.blockTitle}}</h2>
        <div class="block-upcoming-events__list">
          {{#each this.events as |event|}}
            <div class="block-upcoming-events__event">
              <a class="short-date" href={{event.post.url}}>{{this.getShortDate
                  event.starts_at
                }}</a>
              <div class="details">
                <h3 class="title">{{or event.name event.post.topic.title}}</h3>
                <span class="tiny-date">{{formatDate
                    event.starts_at
                    format="tiny"
                  }}</span>
                <span class="long-date">
                  {{this.getLongDate event.starts_at}}</span>
                <DButton
                  class="btn"
                  @icon="eye"
                  @href={{event.post.url}}
                  @translatedLabel={{i18n "js.about.view_more"}}
                />
              </div>
            </div>
          {{/each}}
        </div>
      </div>

    {{/if}}
  </template>

  constructor() {
    super(...arguments);
    const count = this.args?.count || 5;

    this.blockTitle = this.args?.title || "Upcoming Events";

    ajax("discourse-post-event/events").then((results) => {
      this.events = results.events.slice(0, count);
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.events = null;
  }

  getShortDate(startsAt) {
    const eventStartDate = new Date(startsAt);
    return shortDateNoYear(eventStartDate);
  }

  getLongDate(startsAt) {
    const eventStartDate = new Date(startsAt);
    return longDate(eventStartDate);
  }
}
