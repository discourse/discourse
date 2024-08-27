import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

export default class AdminChatIncomingWebhooksList extends Component {
  @service dialog;

  @tracked loading = false;

  get sortedWebhooks() {
    return this.args.webhooks?.sortBy("updated_at").reverse() || [];
  }

  @action
  destroyWebhook(webhook) {
    this.dialog.deleteConfirm({
      message: I18n.t("chat.incoming_webhooks.confirm_destroy"),
      didConfirm: () => {
        this.loading = true;
        return ajax(`/admin/plugins/chat/hooks/${webhook.id}`, {
          type: "DELETE",
        })
          .then(() => {
            this.args.webhooks.removeObject(webhook);
          })
          .catch(popupAjaxError)
          .finally(() => (this.loading = false));
      },
    });
  }

  <template>
    <table>
      <thead>
        <th>{{i18n "chat.incoming_webhooks.name"}}</th>
        <th>{{i18n "chat.incoming_webhooks.emoji"}}</th>
        <th>{{i18n "chat.incoming_webhooks.username"}}</th>
        <th>{{i18n "chat.incoming_webhooks.description"}}</th>
        <th>{{i18n "chat.incoming_webhooks.channel"}}</th>
        <th></th>
      </thead>

      <tbody>
        {{#each this.sortedWebhooks as |webhook|}}
          <tr class="incoming-chat-webhooks-row" data-webhook-id={{webhook.id}}>
            <td>{{webhook.name}}</td>
            <td>{{webhook.emoji}}</td>
            <td>{{webhook.username}}</td>
            <td>{{webhook.description}}</td>
            <td><ChannelTitle @channel={{webhook.chat_channel}} /></td>
            <td>
              <div class="incoming-chat-webhooks-row__controls">
                <!-- TODO: Change what this does, link to Edit page instead -->
                <DButton
                  @icon="pencil-alt"
                  @label="chat.incoming_webhooks.edit"
                  @action={{fn (mut this.selectedWebhookId) webhook.id}}
                  class="btn-small"
                />
                <DButton
                  @icon="trash-alt"
                  @title="chat.incoming_webhooks.delete"
                  @action={{fn this.destroyWebhook webhook}}
                  class="btn-danger btn-small"
                />
              </div>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
