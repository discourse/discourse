import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

export const FITZPATRICK_MODIFIERS = [
  { scale: null, modifier: "" },
  { scale: 2, modifier: ":t1" },
  { scale: 3, modifier: ":t2" },
  { scale: 4, modifier: ":t3" },
  { scale: 5, modifier: ":t4" },
  { scale: 6, modifier: ":t5" },
];

export default class EmojiPicker extends Component {
  @service emojiStore;

  fitzpatrickModifiers = FITZPATRICK_MODIFIERS;

  @action
  didRequestFitzpatrickScale(scale) {
    this.emojiStore.diversity = scale;
    this.api.close();
  }

  @action
  registerApi(api) {
    this.api = api;
  }

  <template>
    <DMenu
      @contentClass="emoji-picker__diversity-menu"
      @triggerClass="emoji-picker__diversity-trigger btn-transparent"
      @onRegisterApi={{this.registerApi}}
    >
      <:trigger>
        {{#if (eq this.emojiStore.diversity 1)}}
          {{dReplaceEmoji ":clap:"}}
        {{else}}
          {{dReplaceEmoji (concat ":clap:t" this.emojiStore.diversity ":")}}
        {{/if}}
      </:trigger>

      <:content>
        <DDropdownMenu as |dropdown|>
          {{#each this.fitzpatrickModifiers as |fitzpatrick|}}
            <dropdown.item>
              <DButton
                class="btn-transparent emoji-picker__diversity-item"
                @action={{fn this.didRequestFitzpatrickScale fitzpatrick.scale}}
                data-level={{fitzpatrick.scale}}
              >
                {{#if fitzpatrick.scale}}
                  {{dReplaceEmoji (concat ":clap:t" fitzpatrick.scale ":")}}
                {{else}}
                  {{dReplaceEmoji ":clap:"}}
                {{/if}}
              </DButton>
            </dropdown.item>
          {{/each}}
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
