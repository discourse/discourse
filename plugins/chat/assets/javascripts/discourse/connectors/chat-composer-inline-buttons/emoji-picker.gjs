import Component from "@glimmer/component";
import { service } from "@ember/service";
import EmojiPicker from "discourse/components/emoji-picker";
import ChatComposerSeparator from "../../components/chat/composer/separator";

export default class ChatEmojiPicker extends Component {
  @service site;

  <template>
    {{#if this.site.desktopView}}
      <EmojiPicker
        @btnClass="chat-composer-button btn-transparent --emoji"
        @context="chat"
        @didSelectEmoji={{@outletArgs.composer.onSelectEmoji}}
      />

      <ChatComposerSeparator />
    {{/if}}
  </template>
}
