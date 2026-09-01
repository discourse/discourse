import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import EmojiPickerContent from "discourse/components/emoji-picker/content";
import DMenu from "discourse/float-kit/components/d-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

export default class EmojiPicker extends Component {
  @tracked menu = null;

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

  @action
  onRegisterMenu(api) {
    this.menu = api;
  }

  <template>
    <DMenu
      @disabled={{@disabled}}
      @groupIdentifier="emoji-picker"
      @identifier="emoji-picker"
      @inline={{@inline}}
      @maxWidth={{405}}
      @modalForMobile={{this.modalForMobile}}
      @onClose={{@onClose}}
      @onRegisterApi={{this.onRegisterMenu}}
      @onShow={{@onShow}}
      @triggerClass={{dConcatClass @btnClass (if this.hasLabel "--has-label")}}
    >
      <:trigger>
        {{#if @emoji}}
          {{dReplaceEmoji (concat ":" @emoji ":")}}
        {{else if this.icon}}
          {{dIcon this.icon}}
        {{/if}}

        {{#if this.triggerLabel}}
          <span class="d-button-label">{{this.triggerLabel}}</span>
        {{else}}
          &#8203;
        {{/if}}

        {{#if @showCaret}}
          {{dIcon this.caretIcon class="emoji-picker__caret"}}
        {{/if}}
      </:trigger>

      <:content>
        <EmojiPickerContent
          @close={{this.menu.close}}
          @context={{this.context}}
          @didSelectEmoji={{@didSelectEmoji}}
        />
      </:content>
    </DMenu>
  </template>
}
