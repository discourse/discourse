import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import ComposerPicker from "discourse/components/composer-picker";
import EmojiPicker from "discourse/components/emoji-picker";
import { composerPickerTabs } from "discourse/lib/composer-picker";
import { withPluginApi } from "discourse/lib/plugin-api";
import { buildChatPickerSelectHandler } from "discourse/plugins/chat/discourse/lib/gif-pick-handler";
import ChatComposerSeparator from "../../components/chat/composer/separator";

export default class ChatComposerPicker extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;

  get composer() {
    return this.args.outletArgs.composer;
  }

  get showUnifiedPicker() {
    return (
      this.siteSettings.enable_unified_composer_picker &&
      this.site.desktopView &&
      composerPickerTabs(getOwner(this)).length > 0
    );
  }

  get showEmojiPicker() {
    return (
      !this.siteSettings.enable_unified_composer_picker && this.site.desktopView
    );
  }

  @action
  onSelect(value, tab) {
    withPluginApi((api) => {
      buildChatPickerSelectHandler({
        api,
        composer: this.composer,
        currentUser: this.currentUser,
      })(value, tab);
    });
  }

  <template>
    {{#if this.showUnifiedPicker}}
      <ComposerPicker
        @onSelect={{this.onSelect}}
        @btnClass="chat-composer-button btn-transparent --emoji"
        @context="chat"
      />

      <ChatComposerSeparator />
    {{else if this.showEmojiPicker}}
      <EmojiPicker
        @didSelectEmoji={{this.composer.onSelectEmoji}}
        @btnClass="chat-composer-button btn-transparent --emoji"
        @context="chat"
      />

      <ChatComposerSeparator />
    {{/if}}
  </template>
}
