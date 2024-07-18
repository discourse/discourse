import Component from "@glimmer/component";
import replaceEmoji from "discourse/helpers/replace-emoji";
import and from "truth-helpers/helpers/and";

export default class TopicMapLink extends Component {
  get linkClasses() {
    return this.args.attachment
      ? "topic-link track-link attachment"
      : "topic-link track-link";
  }

  get truncatedContent() {
    const truncateLength = 85;
    const content = this.args.title || this.args.url;
    return content.length > truncateLength
      ? `${content.slice(0, truncateLength).trim()}...`
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
    >
      {{#if @title}}
        {{replaceEmoji this.truncatedContent}}
      {{else}}
        {{this.truncatedContent}}
      {{/if}}
    </a>
    {{#if (and @title @rootDomain)}}
      <span class="domain">
        {{@rootDomain}}
      </span>
    {{/if}}
  </template>
}
