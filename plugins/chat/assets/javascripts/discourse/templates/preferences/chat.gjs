import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import EmojiPicker from "discourse/components/emoji-picker";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export const CHAT_QUICK_REACTIONS_CUSTOM_DEFAULT = "heart|+1|smile";

export default class Chat extends Component {
  @service chatAudioManager;

  get formData() {
    const userOption = this.args.controller.model.user_option;
    const emojis =
      userOption.chat_quick_reactions_custom?.split("|") ||
      CHAT_QUICK_REACTIONS_CUSTOM_DEFAULT.split("|");

    return {
      chat_enabled: userOption.chat_enabled,
      chat_quick_reaction_type: userOption.chat_quick_reaction_type,
      chat_quick_reactions_custom: emojis,
      only_chat_push_notifications: userOption.only_chat_push_notifications,
      ignore_channel_wide_mention: userOption.ignore_channel_wide_mention,
      chat_sound: userOption.chat_sound,
      chat_header_indicator_preference:
        userOption.chat_header_indicator_preference,
      chat_separate_sidebar_mode: userOption.chat_separate_sidebar_mode,
      chat_send_shortcut: userOption.chat_send_shortcut,
    };
  }

  @action
  handleEmojiSet(index, field, selectedEmoji) {
    let newValue = [...field.value];
    newValue[index] = selectedEmoji;
    field.set(newValue);
  }

  @action
  handleChatSoundSet(sound, { set, name }) {
    if (sound) {
      this.chatAudioManager.play(sound);
    }
    set(name, sound);
  }

  @action
  handleSubmit(data) {
    const { chat_quick_reactions_custom, ...userOptions } = data;
    const shouldReload =
      userOptions.chat_enabled !==
      this.args.controller.model.user_option.chat_enabled;

    this.args.controller.model.set(
      "user_option.chat_quick_reactions_custom",
      chat_quick_reactions_custom.join("|")
    );

    for (const [key, value] of Object.entries(userOptions)) {
      this.args.controller.model.set(`user_option.${key}`, value);
    }
    return this.args.controller.save(shouldReload);
  }

  <template>
    <Form
      @data={{this.formData}}
      @onSubmit={{this.handleSubmit}}
      as |form data|
    >
      <form.Field
        @title={{i18n "chat.enable"}}
        @name="chat_enabled"
        @format="large"
        as |field|
      >
        <field.Checkbox @value={{field.value}} />
      </form.Field>

      <form.Section @title={{i18n "chat.chat_notifications_title"}}>
        <form.Field
          @title={{i18n "chat.only_chat_push_notifications.title"}}
          @name="only_chat_push_notifications"
          @format="large"
          as |field|
        >
          <field.Checkbox @value={{field.value}} />
        </form.Field>
        <form.Field
          @title={{i18n "chat.ignore_channel_wide_mention.title"}}
          @name="ignore_channel_wide_mention"
          @format="large"
          as |field|
        >
          <field.Checkbox @value={{field.value}} />
        </form.Field>

        <form.Field
          @title={{i18n "chat.sound.title"}}
          @name="chat_sound"
          @format="large"
          @onSet={{this.handleChatSoundSet}}
          as |field|
        >
          <field.Select as |select|>
            {{#each @controller.chatSounds as |sound|}}
              <select.Option @value={{sound.value}}>
                {{sound.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <form.Field
          @title={{i18n "chat.header_indicator_preference.title"}}
          @name="chat_header_indicator_preference"
          @format="large"
          as |field|
        >
          <field.Select @includeNone={{false}} as |select|>
            {{#each @controller.headerIndicatorOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>
        <form.Field
          @title={{i18n "chat.separate_sidebar_mode.title"}}
          @name="chat_separate_sidebar_mode"
          @format="large"
          as |field|
        >
          <field.Select @includeNone={{false}} as |select|>
            {{#each @controller.chatSeparateSidebarModeOptions as |option|}}
              <select.Option @value={{option.value}}>
                {{option.name}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>
      </form.Section>
      <form.Section @title={{i18n "chat.personalization_title"}}>
        <form.Field
          @title={{i18n "chat.quick_reaction_type.title"}}
          @name="chat_quick_reaction_type"
          @format="large"
          as |field|
        >
          <field.RadioGroup as |radioGroup|>
            {{#each @controller.chatQuickReactionTypes as |option|}}
              <radioGroup.Radio @value={{option.value}}>
                {{option.label}}
              </radioGroup.Radio>
            {{/each}}
          </field.RadioGroup>
        </form.Field>

        {{#if (eq data.chat_quick_reaction_type "custom")}}
          <form.Field
            @title={{i18n "chat.quick_reaction_type.options.custom"}}
            @name="chat_quick_reactions_custom"
            @format="large"
            as |field|
          >
            <field.Custom>

              {{#each data.chat_quick_reactions_custom as |emoji index|}}
                <EmojiPicker
                  @emoji={{emoji}}
                  @btnClass="btn-default"
                  @context="chat_preferences"
                  @didSelectEmoji={{fn this.handleEmojiSet index field}}
                />
              {{/each}}
            </field.Custom>
          </form.Field>
        {{/if}}
        <form.Field
          @title={{i18n "chat.send_shortcut.title"}}
          @name="chat_send_shortcut"
          @format="large"
          as |field|
        >
          <field.RadioGroup as |radioGroup|>
            {{#each @controller.chatSendShortcutOptions as |option|}}
              <radioGroup.Radio @value={{option.value}}>
                {{option.label}}
              </radioGroup.Radio>
            {{/each}}
          </field.RadioGroup>
        </form.Field>
      </form.Section>
      <form.Submit />
    </Form>
  </template>
}
