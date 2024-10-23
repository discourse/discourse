import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
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
      didConfirm: async () => {
        this.loading = true;

        try {
          await ajax(`/admin/plugins/chat/hooks/${webhook.id}`, {
            type: "DELETE",
          });
          this.args.webhooks.removeObject(webhook);
        } catch (err) {
          popupAjaxError(err);
        } finally {
          this.loading = false;
        }
      },
    });
  }

  <template>
    <table class="d-admin-table">
      <thead>
        <th>{{i18n "chat.incoming_webhooks.name"}}</th>
        <th>{{i18n "chat.incoming_webhooks.emoji"}}</th>
        <th>{{i18n "chat.incoming_webhooks.username"}}</th>
        {{!-- <th>{{i18n "chat.incoming_webhooks.description"}}</th> --}}
        <th>{{i18n "chat.incoming_webhooks.channel"}}</th>
        <th></th>
      </thead>

      <tbody>
        {{#each this.sortedWebhooks as |webhook|}}
          <tr
            class="d-admin-row__content incoming-chat-webhooks-row"
            data-webhook-id={{webhook.id}}
          >
            <td class="d-admin-row__overview">
              <div class="d-admin-row__overview-name">
                {{webhook.name}}
              </div>
              <div class="d-admin-row__overview-about">
                {{webhook.description}}
              </div>
            </td>
            <td class="d-admin-row__detail">
              <div class="d-admin-row__mobile-label">
                {{i18n "chat.incoming_webhooks.emoji"}}
              </div>
              {{replaceEmoji webhook.emoji}}
            </td>
            <td class="d-admin-row__detail">
              <div class="d-admin-row__mobile-label">
                {{i18n "chat.incoming_webhooks.username"}}
              </div>
              {{webhook.username}}
            </td>
            {{!-- <td class="d-admin-row__overview">
              <div class="d-admin-row__mobile-label">
                {{i18n "chat.incoming_webhooks.description"}}
              </div>
              
            </td> --}}
            <td class="d-admin-row__detail">
              <div class="d-admin-row__mobile-label">
                {{i18n "chat.incoming_webhooks.channel"}}
              </div>
              <ChannelTitle @channel={{webhook.chat_channel}} />
            </td>
            <td
              class="d-admin-row__controls incoming-chat-webhooks-row__controls"
            >
              <div class="d-admin-row__controls-options">
                <LinkTo
                  @route="adminPlugins.show.discourse-chat-incoming-webhooks.show"
                  @model={{webhook.id}}
                  class="btn btn-small admin-chat-incoming-webhooks-edit"
                >{{i18n "chat.incoming_webhooks.edit"}}</LinkTo>

                <DButton
                  @icon="trash-alt"
                  @title="chat.incoming_webhooks.delete"
                  @action={{fn this.destroyWebhook webhook}}
                  class="btn-danger btn-small admin-chat-incoming-webhooks-delete"
                />
              </div>
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
