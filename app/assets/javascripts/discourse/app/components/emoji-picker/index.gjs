import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import EmojiPickerContent from "discourse/components/emoji-picker/content";
import replaceEmoji from "discourse/helpers/replace-emoji";
import icon from "discourse-common/helpers/d-icon";
import DMenu from "float-kit/components/d-menu";

export default class EmojiPicker extends Component {
  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  get icon() {
    return this.args.icon ?? "discourse-emojis";
  }

  <template>
    <DMenu
      @triggerClass={{@btnClass}}
      @contentClass="emoji-picker__menu"
      @onRegisterApi={{this.onRegisterMenu}}
      @identifier="emoji-picker"
      @groupIdentifier="emoji-picker"
      @modalForMobile={{true}}
      @maxWidth={{405}}
    >
      <:trigger>
        {{#if @icon}}
          {{replaceEmoji (concat ":" @icon ":")}}
        {{else}}
          {{icon "discourse-emojis"}}
        {{/if}}
      </:trigger>

      <:content>
        <EmojiPickerContent
          @close={{this.menu.close}}
          @didSelectEmoji={{@didSelectEmoji}}
        />
      </:content>
    </DMenu>
  </template>
}
