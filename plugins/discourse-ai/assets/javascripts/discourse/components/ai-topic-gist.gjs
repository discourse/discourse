import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TABLE_AI_LAYOUT } from "../services/gists";

export default class AiTopicGist extends Component {
  @service gists;

  get shouldShow() {
    return (
      this.gists.currentPreference === TABLE_AI_LAYOUT && this.gists.showToggle
    );
  }

  get hasGist() {
    return !!this.gist;
  }

  get gist() {
    return this.args.topic.get("ai_topic_gist");
  }

  get escapedExcerpt() {
    return this.args.topic.get("escapedExcerpt");
  }

  <template>
    {{#if this.shouldShow}}
      {{#if this.hasGist}}
        <a href={{@topic.lastUnreadUrl}} class="excerpt">
          <div class="excerpt__contents">{{this.gist}}</div>
        </a>
      {{else}}
        {{#if this.escapedExcerpt}}
          <a href={{@topic.lastUnreadUrl}} class="excerpt">
            <div class="excerpt__contents">
              {{htmlSafe this.escapedExcerpt}}
            </div>
          </a>
        {{/if}}
      {{/if}}
    {{/if}}
  </template>
}
