import Component from "@glimmer/component";
import { action } from "@ember/object";
import EmojiPickerContent from "discourse/components/emoji-picker/content";
import icon from "discourse-common/helpers/d-icon";
import DMenu from "float-kit/components/d-menu";

export default class EmojiPicker extends Component {
  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  <template>
    <DMenu
      @triggerClass={{@btnClass}}
      @contentClass="emoji-picker__menu"
      @onRegisterApi={{this.onRegisterMenu}}
      @closeOnScroll={{true}}
      @identifier="emoji-picker"
      @groupIdentifier="emoji-picker"
      @interactive={{true}}
      @modalForMobile={{true}}
    >
      <:trigger>
        {{icon "discourse-emojis"}}
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
