import Component from "@glimmer/component";
import { not } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class PostMetaDataPosterNameIcon extends Component {
  get emojis() {
    if (!this.args.emoji) {
      return;
    }

    return this.args.emoji.split("|");
  }

  get skipEmojiTitle() {
    return !this.args.emojiTitle;
  }

  <template>
    <span class={{dConcatClass "poster-icon" @className}} title={{@title}}>
      {{#if @url}}
        <a href={{@url}}>
          <Content
            @icon={{@icon}}
            @emojis={{this.emojis}}
            @emojiTitle={{@emojiTitle}}
            @text={{@text}}
          />
        </a>
      {{else}}
        <Content
          @icon={{@icon}}
          @emojis={{this.emojis}}
          @emojiTitle={{@emojiTitle}}
          @text={{@text}}
        />
      {{/if}}
    </span>
  </template>
}

const Content = <template>
  {{#if @icon}}
    {{dIcon @icon}}
  {{else if @emojis}}
    {{#each @emojis as |emojiName|}}
      {{dEmoji emojiName skipEmojiTitle=(not @emojiTitle)}}
    {{/each}}
  {{/if}}
  {{@text}}
</template>;
