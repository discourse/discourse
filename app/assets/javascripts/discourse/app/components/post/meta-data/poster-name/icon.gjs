import Component from "@glimmer/component";
import { not } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import emoji from "discourse/helpers/emoji";

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
    <span class={{concatClass "poster-icon" @className}} title={{@title}}>
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
    {{icon @icon}}
  {{else if @emojis}}
    {{#each @emojis as |emojiName|}}
      {{emoji emojiName skipEmojiTitle=(not @emojiTitle)}}
    {{/each}}
  {{/if}}
  {{@text}}
</template>;
