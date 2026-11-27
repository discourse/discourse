import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

/** @type {{ scale: number | null, modifier: string }[]} */
export const FITZPATRICK_MODIFIERS = [
  { scale: null, modifier: "" },
  { scale: 2, modifier: ":t1" },
  { scale: 3, modifier: ":t2" },
  { scale: 4, modifier: ":t3" },
  { scale: 5, modifier: ":t4" },
  { scale: 6, modifier: ":t5" },
];

/** The skin tones by the store's scale, where 1 is no tone. */
const SKIN_TONES = [
  { scale: 1, clap: "clap", name: "default_tone" },
  { scale: 2, clap: "clap:t2", name: "light_tone" },
  { scale: 3, clap: "clap:t3", name: "medium_light_tone" },
  { scale: 4, clap: "clap:t4", name: "medium_tone" },
  { scale: 5, clap: "clap:t5", name: "medium_dark_tone" },
  { scale: 6, clap: "clap:t6", name: "dark_tone" },
];

export default class EmojiPicker extends Component {
  @service emojiStore;
  @service siteSettings;

  fitzpatrickModifiers = FITZPATRICK_MODIFIERS;

  /** The tones as options, named by their translated tone names. */
  get toneOptions() {
    return SKIN_TONES.map((tone) =>
      selectOption(tone, { label: i18n(`emoji_picker.${tone.name}`) })
    );
  }

  @action
  changeTone(scale) {
    this.emojiStore.diversity = scale;
  }

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
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelect
        class="emoji-picker__diversity-trigger"
        @clearMode="never"
        @identifier="emoji-picker-diversity"
        @onChange={{this.changeTone}}
        @options={{this.toneOptions}}
        @placement="bottom-end"
        @selectedIcon="check"
        @showCaret={{false}}
        @texts={{hash ariaLabel=(i18n "emoji_picker.skin_tone")}}
        @value={{this.emojiStore.diversity}}
        @valueField="scale"
        @variant="static"
      >
        <:selection as |option|>
          {{dEmoji option.record.clap (hash alt="" skipTitle=true)}}
          <span class="sr-only">{{option.label}}</span>
        </:selection>
        <:option as |option|>
          {{dEmoji option.record.clap (hash alt="" skipTitle=true)}}
          {{option.label}}
        </:option>
      </DSelect>
    {{else}}
      <DMenu
        @contentClass="emoji-picker__diversity-menu"
        @onRegisterApi={{this.registerApi}}
        @triggerClass="emoji-picker__diversity-trigger btn-transparent"
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
                  data-level={{fitzpatrick.scale}}
                  @action={{fn
                    this.didRequestFitzpatrickScale
                    fitzpatrick.scale
                  }}
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
    {{/if}}
  </template>
}
