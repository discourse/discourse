import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import EmojiPicker from "discourse/components/emoji-picker";
import Form from "discourse/components/form";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ChatChannelChooser from "discourse/plugins/chat/discourse/components/chat-channel-chooser";

export default class ChatIncomingWebhookEditForm extends Component {
  @service toasts;
  @service router;

  @tracked emojiPickerIsActive = false;

  get formData() {
    return {
      name: this.args.webhook?.name,
      description: this.args.webhook?.description,
      username: this.args.webhook?.username,
      chat_channel_id: this.args.webhook?.chat_channel.id,
      emoji: this.args.webhook?.emoji,
    };
  }

  @action
  emojiSelected(setData, emoji) {
    setData("emoji", `:${emoji}:`);
    this.emojiPickerIsActive = false;
  }

  @action
  resetEmoji(setData) {
    setData("emoji", null);
  }

  @action
  async save(data) {
    try {
      if (this.args.webhook?.id) {
        await ajax(`/admin/plugins/chat/hooks/${this.args.webhook.id}`, {
          data,
          type: "PUT",
        });

        this.toasts.success({
          duration: 3000,
          data: {
            message: i18n("chat.incoming_webhooks.saved"),
          },
        });
      } else {
        const webhook = await ajax(`/admin/plugins/chat/hooks`, {
          data,
          type: "POST",
        });

        this.toasts.success({
          duration: 3000,
          data: {
            message: i18n("chat.incoming_webhooks.created"),
          },
        });

        this.router
          .transitionTo(
            "adminPlugins.show.discourse-chat-incoming-webhooks.edit",
            webhook
          )
          .then(() => {
            this.router.refresh();
          });
      }
    } catch (err) {
      popupAjaxError(err);
    }
  }

  <template>
    <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @name="name"
        @title={{i18n "chat.incoming_webhooks.name"}}
        @validation="required"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="description"
        @title={{i18n "chat.incoming_webhooks.description"}}
        as |field|
      >
        <field.Textarea />
      </form.Field>

      <form.Field
        @name="username"
        @title={{i18n "chat.incoming_webhooks.username"}}
        @description={{i18n "chat.incoming_webhooks.username_instructions"}}
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="chat_channel_id"
        @title={{i18n "chat.incoming_webhooks.post_to"}}
        @validation="required"
        as |field|
      >
        <field.Custom>
          <ChatChannelChooser
            @content={{@chatChannels}}
            @value={{field.value}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="emoji"
        @title={{i18n "chat.incoming_webhooks.emoji"}}
        @description={{i18n "chat.incoming_webhooks.emoji_instructions"}}
        as |field|
      >
        <field.Custom>
          {{#if field.value}}
            {{i18n "chat.incoming_webhooks.current_emoji"}}

            <span class="incoming-chat-webhooks-current-emoji">
              {{replaceEmoji field.value}}
            </span>
          {{/if}}

          <EmojiPicker
            @isActive={{this.emojiPickerIsActive}}
            @isEditorFocused={{true}}
            @emojiSelected={{fn this.emojiSelected form.set}}
            @onEmojiPickerClose={{fn (mut this.emojiPickerIsActive) false}}
          />

          {{#unless this.emojiPickerIsActive}}
            <form.Row as |row|>
              <row.Col @size={{6}}>
                <DButton
                  @label="chat.incoming_webhooks.select_emoji"
                  @action={{fn (mut this.emojiPickerIsActive) true}}
                  class="btn-primary admin-chat-webhooks-select-emoji"
                />
              </row.Col>
              <row.Col @size={{6}}>
                <DButton
                  @label="chat.incoming_webhooks.reset_emoji"
                  @action={{fn this.resetEmoji form.set}}
                  @disabled={{not field.value}}
                  class="admin-chat-webhooks-clear-emoji"
                />
              </row.Col>
            </form.Row>
          {{/unless}}

        </field.Custom>
      </form.Field>

      {{#if @webhook.url}}
        <form.Container
          @name="url"
          @title={{i18n "chat.incoming_webhooks.url"}}
          @subtitle={{i18n "chat.incoming_webhooks.url_instructions"}}
        >
          <code>{{@webhook.url}}</code>
        </form.Container>
      {{/if}}

      <form.Submit />
    </Form>
  </template>
}
