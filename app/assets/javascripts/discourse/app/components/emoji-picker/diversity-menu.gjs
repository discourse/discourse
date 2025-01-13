import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import replaceEmoji from "discourse/helpers/replace-emoji";
import DMenu from "float-kit/components/d-menu";

export const FITZPATRICK_MODIFIERS = [
  { scale: 1, modifier: null },
  { scale: 2, modifier: ":t2" },
  { scale: 3, modifier: ":t3" },
  { scale: 4, modifier: ":t4" },
  { scale: 5, modifier: ":t5" },
  { scale: 6, modifier: ":t6" },
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
          {{replaceEmoji ":clap:"}}
        {{else}}
          {{replaceEmoji (concat ":clap:t" this.emojiStore.diversity ":")}}
        {{/if}}
      </:trigger>

      <:content>
        <DropdownMenu as |dropdown|>
          {{#each this.fitzpatrickModifiers as |fitzpatrick|}}
            <dropdown.item>
              <DButton
                class="btn-transparent emoji-picker__diversity-item"
                @action={{fn this.didRequestFitzpatrickScale fitzpatrick.scale}}
                data-level={{fitzpatrick.scale}}
              >
                {{#if (eq fitzpatrick.scale 1)}}
                  {{replaceEmoji ":clap:"}}
                {{else}}
                  {{replaceEmoji (concat ":clap:t" fitzpatrick.scale ":")}}
                {{/if}}
              </DButton>
            </dropdown.item>
          {{/each}}
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
