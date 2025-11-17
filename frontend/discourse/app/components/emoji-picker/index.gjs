import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import EmojiPickerContent from "discourse/components/emoji-picker/content";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";

export default class EmojiPicker extends Component {
  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  get icon() {
    return this.args.icon ?? "far-face-smile";
  }

  get context() {
    return this.args.context ?? "topic";
  }

  get modalForMobile() {
    return this.args.modalForMobile ?? true;
  }

  <template>
    <DMenu
      @triggerClass={{concatClass @btnClass}}
      @onRegisterApi={{this.onRegisterMenu}}
      @identifier="emoji-picker"
      @groupIdentifier="emoji-picker"
      @modalForMobile={{this.modalForMobile}}
      @maxWidth={{405}}
      @onShow={{@onShow}}
      @onClose={{@onClose}}
    >
      <:trigger>
        {{#if @emoji}}
          {{replaceEmoji (concat ":" @emoji ":")}}
        {{else}}
          {{icon this.icon}}
        {{/if}}

        {{#if @label}}
          <span class="d-button-label">{{@label}}</span>
        {{else}}
          &#8203;
        {{/if}}
      </:trigger>

      <:content>
        <EmojiPickerContent
          @close={{this.menu.close}}
          @didSelectEmoji={{@didSelectEmoji}}
          @context={{this.context}}
        />
      </:content>
    </DMenu>
  </template>
}
