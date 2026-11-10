import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DiscoursePostEvent from "discourse/plugins/discourse-events/discourse/components/discourse-post-event";

export default class DiscoursePostEventOneboxPreview extends Component {
  @service discoursePostEventApi;

  @tracked event = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  get fallback() {
    return trustHTML(this.args.fallbackHtml);
  }

  async load() {
    this.event = await this.discoursePostEventApi.cachedEventByTopicId(
      this.args.topicId
    );
  }

  <template>
    {{#if this.event}}
      <div class="discourse-post-event-onebox">
        <DiscoursePostEvent
          @event={{this.event}}
          @linkToPost={{true}}
          @readOnly={{@readOnly}}
        />
      </div>
    {{else}}
      {{this.fallback}}
    {{/if}}
  </template>
}
