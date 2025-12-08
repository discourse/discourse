import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default <template>
  <Form
    @data={{@controller.formData}}
    @onSubmit={{@controller.saveForm}}
    as |form|
  >
    <label class="control-label">{{i18n "chat.title_capitalized"}}</label>

    <form.Field
      @name="chat_enabled"
      @title={{i18n "chat.enable"}}
      class="control-group chat-setting"
      data-setting-name="user_chat_enabled"
      as |field|
    >
      <field.Checkbox />
    </form.Field>

    <form.Field
      @name="chat_quick_reaction_type"
      @title={{i18n "chat.quick_reaction_type.title"}}
      class="control-group chat-setting"
      data-setting-name="user_chat_quick_reaction_type"
      as |field|
    >
      <field.RadioGroup as |radioGroup|>
        {{#each @controller.chatQuickReactionTypes as |option|}}
          <radioGroup.Radio @value={{option.value}}>
            {{option.label}}
          </radioGroup.Radio>
        {{/each}}
        {{#if (eq field.value "custom")}}
          <div class="controls tracking-controls emoji-pickers">
            <form.Field
              @name="chat_quick_reactions_custom_0"
              @title=" "
              @showTitle={{false}}
              as |emojiField|
            >
              <emojiField.Emoji @context="chat_preferences" />
            </form.Field>
            <form.Field
              @name="chat_quick_reactions_custom_1"
              @title=" "
              @showTitle={{false}}
              as |emojiField|
            >
              <emojiField.Emoji @context="chat_preferences" />
            </form.Field>
            <form.Field
              @name="chat_quick_reactions_custom_2"
              @title=" "
              @showTitle={{false}}
              as |emojiField|
            >
              <emojiField.Emoji @context="chat_preferences" />
            </form.Field>
          </div>
        {{/if}}
      </field.RadioGroup>
    </form.Field>

    <form.Field
      @name="only_chat_push_notifications"
      @title={{i18n "chat.only_chat_push_notifications.title"}}
      @description={{i18n "chat.only_chat_push_notifications.description"}}
      class="control-group chat-setting"
      data-setting-name="user_chat_only_push_notifications"
      as |field|
    >
      <field.Checkbox />
    </form.Field>

    <form.Field
      @name="ignore_channel_wide_mention"
      @title={{i18n "chat.ignore_channel_wide_mention.title"}}
      @description={{i18n "chat.ignore_channel_wide_mention.description"}}
      class="control-group chat-setting"
      data-setting-name="user_chat_ignore_channel_wide_mention"
      as |field|
    >
      <field.Checkbox />
    </form.Field>

    <form.Field
      @name="chat_sound"
      @title={{i18n "chat.sound.title"}}
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_sounds"
      @onSet={{@controller.onSetChatSound}}
      as |field|
    >
      <field.Select @includeNone={{true}} as |select|>
        {{#each @controller.chatSounds as |sound|}}
          <select.Option @value={{sound.value}}>
            {{sound.name}}
          </select.Option>
        {{/each}}
      </field.Select>
    </form.Field>

    <form.Field
      @name="chat_header_indicator_preference"
      @title={{i18n "chat.header_indicator_preference.title"}}
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_header_indicator_preference"
      as |field|
    >
      <field.Select as |select|>
        {{#each @controller.headerIndicatorOptions as |option|}}
          <select.Option @value={{option.value}}>
            {{option.name}}
          </select.Option>
        {{/each}}
      </field.Select>
    </form.Field>

    <form.Field
      @name="chat_separate_sidebar_mode"
      @title={{i18n "chat.separate_sidebar_mode.title"}}
      class="control-group chat-setting controls-dropdown"
      data-setting-name="user_chat_separate_sidebar_mode"
      as |field|
    >
      <field.Select as |select|>
        {{#each @controller.chatSeparateSidebarModeOptions as |option|}}
          <select.Option @value={{option.value}}>
            {{option.name}}
          </select.Option>
        {{/each}}
      </field.Select>
    </form.Field>

    <form.Field
      @name="chat_send_shortcut"
      @title=" "
      @showTitle={{false}}
      class="control-group chat-setting"
      data-setting-name="user_chat_send_shortcut"
      as |field|
    >
      <field.RadioGroup as |radioGroup|>
        {{#each @controller.chatSendShortcutOptions as |option|}}
          <radioGroup.Radio @value={{option.value}}>
            <radioGroup.Radio.Title>{{option.label}}</radioGroup.Radio.Title>
            <radioGroup.Radio.Description
            >{{option.description}}</radioGroup.Radio.Description>
          </radioGroup.Radio>
        {{/each}}
      </field.RadioGroup>
    </form.Field>

    <form.Submit @id="user_chat_preference_save" />
  </Form>
</template>
