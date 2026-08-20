import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import Dates from "./dates";
import DiscoursePostEventLocation from "./location";

export default class DiscoursePostEventOneboxPreview extends Component {
  @service discoursePostEventApi;

  @tracked event = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    this.event = await this.discoursePostEventApi.cachedEventByTopicId(
      this.args.topicId
    );
  }

  get eventName() {
    return this.event.name || this.event.post?.topic?.title;
  }

  get startsAtMonth() {
    return this.#displayTime(this.event.startsAt).format("MMM");
  }

  get startsAtDay() {
    return this.#displayTime(this.event.startsAt).format("D");
  }

  get fallback() {
    return trustHTML(this.args.fallbackHtml);
  }

  #displayTime(time) {
    if (this.event.allDay) {
      return moment(time, "YYYY-MM-DD");
    } else if (this.event.showLocalTime) {
      return moment.tz(time, this.event.timezone || "UTC");
    }
    return moment.utc(time).tz(moment.tz.guess());
  }

  <template>
    {{#if this.event}}
      <div class="discourse-post-event discourse-post-event--preview">
        <div class="discourse-post-event-widget">
          <header class="event-header">
            <div class="event-date">
              <div class="month">{{this.startsAtMonth}}</div>
              <div class="day">{{this.startsAtDay}}</div>
            </div>
            <div class="event-info">
              <span class="name">{{dReplaceEmoji this.eventName}}</span>
            </div>
          </header>
          <Dates @event={{this.event}} />
          <DiscoursePostEventLocation @event={{this.event}} />
        </div>
      </div>
    {{else}}
      {{this.fallback}}
    {{/if}}
  </template>
}
