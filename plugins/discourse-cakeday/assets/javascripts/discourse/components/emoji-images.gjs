/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import computed from "discourse/lib/decorators";
import { emojiUnescape } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

@classNames("emoji-images")
export default class EmojiImages extends Component {
  @computed("list")
  emojiHTML(list) {
    return list
      .split("|")
      .map((et) => emojiUnescape(`:${et}:`, { skipTitle: true }));
  }

  @computed("title")
  titleText(title) {
    return i18n(title);
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
