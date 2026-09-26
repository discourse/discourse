import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class EmojiImages extends Component {
  @service siteSettings;

  get emojiHTML() {
    return this.args.list
      .split("|")
      .map((et) => emojiUnescape(`:${et}:`, { skipTitle: true }));
  }

  get titleText() {
    return i18n(this.args.title);
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
