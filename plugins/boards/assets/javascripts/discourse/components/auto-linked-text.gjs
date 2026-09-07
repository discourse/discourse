import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { generateLinkifyFunction } from "discourse/lib/text";

let cachedLinkify = null;

export default class AutoLinkedText extends Component {
  @tracked linkify = cachedLinkify;

  constructor() {
    super(...arguments);
    if (!this.linkify) {
      generateLinkifyFunction({}).then((instance) => {
        cachedLinkify = instance;
        if (!this.isDestroying && !this.isDestroyed) {
          this.linkify = instance;
        }
      });
    }
  }

  get segments() {
    const text = this.args.text ?? "";
    if (!this.linkify || !text) {
      return [{ isUrl: false, value: text }];
    }

    const matches = this.linkify.match(text);
    if (!matches) {
      return [{ isUrl: false, value: text }];
    }

    const result = [];
    let lastIndex = 0;

    for (const match of matches) {
      if (match.index > lastIndex) {
        result.push({
          isUrl: false,
          value: text.slice(lastIndex, match.index),
        });
      }
      result.push({ isUrl: true, value: match.raw, href: match.url });
      lastIndex = match.index + match.raw.length;
    }

    if (lastIndex < text.length) {
      result.push({ isUrl: false, value: text.slice(lastIndex) });
    }

    return result;
  }

  <template>
    {{#each this.segments as |segment|}}
      {{#if segment.isUrl}}
        <a
          href={{segment.href}}
          target="_blank"
          rel="noopener noreferrer"
        >{{segment.value}}</a>
      {{else}}
        {{segment.value}}
      {{/if}}
    {{/each}}
  </template>
}
