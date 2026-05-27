/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { emojiUnescape } from "discourse/lib/text";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("")
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
    <div class="emoji-images" ...attributes>
      {{#if this.siteSettings.enable_emoji}}
        <div title={{this.titleText}}>
          {{#each this.emojiHTML as |html|}}
            {{trustHTML html}}
          {{/each}}
        </div>
      {{else}}
        {{dIcon "cake-candles" title=this.titleText}}
      {{/if}}
    </div>
  </template>
}
