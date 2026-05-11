import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import EmojiPickerContent from "discourse/components/emoji-picker/content";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";

export default class EmojiPicker extends Component {
  @tracked menu = null;

  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  get icon() {
    return this.args.icon === undefined ? "far-face-smile" : this.args.icon;
  }

  get context() {
    return this.args.context ?? "topic";
  }

  get modalForMobile() {
    return this.args.modalForMobile ?? true;
  }

  get triggerLabel() {
    if (this.args.label !== undefined) {
      return this.args.label;
    }
    if (this.args.emoji && this.args.showSelectedName) {
      return this.args.emoji;
    }
    return null;
  }

  get caretIcon() {
    return this.menu?.expanded ? "angle-up" : "angle-down";
  }

  get hasLabel() {
    return this.args.emoji && this.triggerLabel;
  }

  <template>
    <DMenu
      @triggerClass={{concatClass @btnClass (if this.hasLabel "--has-label")}}
      @onRegisterApi={{this.onRegisterMenu}}
      @identifier="emoji-picker"
      @groupIdentifier="emoji-picker"
      @modalForMobile={{this.modalForMobile}}
      @maxWidth={{405}}
      @onShow={{@onShow}}
      @onClose={{@onClose}}
      @inline={{@inline}}
      @disabled={{@disabled}}
    >
      <:trigger>
        {{#if @emoji}}
          {{replaceEmoji (concat ":" @emoji ":")}}
        {{else if this.icon}}
          {{icon this.icon}}
        {{/if}}

        {{#if this.triggerLabel}}
          <span class="d-button-label">{{this.triggerLabel}}</span>
        {{else}}
          &#8203;
        {{/if}}

        {{#if @showCaret}}
          {{icon this.caretIcon class="emoji-picker__caret"}}
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
