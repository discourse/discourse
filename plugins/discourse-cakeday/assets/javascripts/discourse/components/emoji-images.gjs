/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { emojiUnescape } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

@classNames("emoji-images")
export default class EmojiImages extends Component {
  @computed("list")
  get emojiHTML() {
    return this.list
      .split("|")
      .map((et) => emojiUnescape(`:${et}:`, { skipTitle: true }));
  }

  @computed("title")
  get titleText() {
    return i18n(this.title);
  }

  <template>
    {{#if this.siteSettings.enable_emoji}}
      <div title={{this.titleText}}>
        {{#each this.emojiHTML as |html|}}
          {{htmlSafe html}}
        {{/each}}
      </div>
    {{else}}
      {{icon "cake-candles" title=this.titleText}}
    {{/if}}
  </template>
}
