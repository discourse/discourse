import Component from "@glimmer/component";
import { and } from "truth-helpers";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { i18n } from "discourse-i18n";

const TRUNCATE_LENGTH_LIMIT = 85;

export default class TopicMapLink extends Component {
  get linkClasses() {
    return this.args.attachment
      ? "topic-link track-link attachment"
      : "topic-link track-link";
  }

  get truncatedContent() {
    const content = this.args.title || this.args.url;
    return content.length > TRUNCATE_LENGTH_LIMIT
      ? `${content.slice(0, TRUNCATE_LENGTH_LIMIT).trim()}...`
      : content;
  }

  <template>
    <a
      class={{this.linkClasses}}
      href={{@url}}
      title={{@url}}
      data-user-id={{@userId}}
      data-ignore-post-id="true"
      target="_blank"
      rel="nofollow ugc noopener noreferrer"
      data-clicks={{@clickCount}}
      aria-label={{i18n "topic_map.clicks" count=@clickCount}}
    >
      <span class="content">
        {{#if @title}}
          {{replaceEmoji this.truncatedContent}}
        {{else}}
          {{this.truncatedContent}}
        {{/if}}
      </span>
    </a>
    {{#if (and @title @rootDomain)}}
      <span class="domain">
        {{@rootDomain}}
      </span>
    {{/if}}
  </template>
}
