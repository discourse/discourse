import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import EmojiPicker from "discourse/components/emoji-picker";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import ChatChannelChooser from "discourse/plugins/chat/discourse/components/chat-channel-chooser";

export default class ChatIncomingWebhookEditForm extends Component {
  @service toasts;
  @service router;

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
          duration: "short",
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
          duration: "short",
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
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="description"
        @title={{i18n "chat.incoming_webhooks.description"}}
        @type="textarea"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="username"
        @title={{i18n "chat.incoming_webhooks.username"}}
        @description={{i18n "chat.incoming_webhooks.username_instructions"}}
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="chat_channel_id"
        @title={{i18n "chat.incoming_webhooks.post_to"}}
        @validation="required"
        @type="custom"
        as |field|
      >
        <field.Control>
          <ChatChannelChooser
            @content={{@chatChannels}}
            @value={{field.value}}
            @onChange={{field.set}}
          />
        </field.Control>
      </form.Field>

      <form.Field
        @name="emoji"
        @title={{i18n "chat.incoming_webhooks.emoji"}}
        @description={{i18n "chat.incoming_webhooks.emoji_instructions"}}
        @size="large"
        @type="custom"
        as |field|
      >
        <field.Control>
          {{#if field.value}}
            {{i18n "chat.incoming_webhooks.current_emoji"}}

            <span class="incoming-chat-webhooks-current-emoji">
              {{dReplaceEmoji field.value}}
            </span>
          {{/if}}

          <form.Row as |row|>
            <row.Col @size={{2}}>
              <EmojiPicker @didSelectEmoji={{fn this.emojiSelected form.set}} />
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
        </field.Control>
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
