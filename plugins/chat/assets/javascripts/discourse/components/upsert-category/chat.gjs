import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import EmptyState from "discourse/components/empty-state";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

function channelSettingsUrl(channel) {
  return getURL(`/chat/c/${channel.slug || "-"}/${channel.id}/info/settings`);
}

function channelColorStyle(channel) {
  return htmlSafe(`color: #${channel.chatable?.color || "000"}`);
}

function channelIcon(channel) {
  return channel.emoji ? replaceEmoji(`:${channel.emoji}:`) : icon("d-chat");
}

export default class EditCategoryChat extends Component {
  @tracked channels = null;
  @tracked loading = true;

  @action
  async loadChannels() {
    try {
      this.loading = true;
      const result = await ajax(
        `/chat/api/channels?chatable_id=${this.args.category.id}&chatable_type=Category`
      );
      this.channels = (result.channels || []).sort((a, b) =>
        (a.title || "").localeCompare(b.title || "")
      );
    } catch (err) {
      popupAjaxError(err);
      this.channels = [];
    } finally {
      this.loading = false;
    }
  }

  <template>
    <section class="edit-category-chat" {{didInsert this.loadChannels}}>
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.channels.length}}
          <table class="d-table edit-category-chat__table">
            <thead class="d-table__header">
              <tr class="d-table__row">
                <th class="d-table__header-cell">{{i18n
                    "chat.edit_category.channel"
                  }}</th>
                <th class="d-table__header-cell">{{i18n
                    "chat.edit_category.description"
                  }}</th>
                <th class="d-table__header-cell"></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.channels as |channel|}}
                <tr class="d-table__row">
                  <td class="d-table__cell edit-category-chat__channel-name">
                    <span
                      class="chat-channel-icon --icon"
                      style={{channelColorStyle channel}}
                    >
                      {{channelIcon channel}}
                    </span>
                    <span>{{channel.title}}</span>
                  </td>
                  <td
                    class="d-table__cell edit-category-chat__channel-description"
                  >
                    {{if channel.description channel.description "-"}}
                  </td>
                  <td
                    class="d-table__cell edit-category-chat__channel-actions d-table__cell-actions"
                  >
                    <a
                      href={{channelSettingsUrl channel}}
                      class="btn btn-default btn-small"
                    >
                      {{icon "gear"}}
                      {{i18n "chat.edit_category.settings"}}
                    </a>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          <EmptyState
            @title={{i18n "chat.edit_category.no_channels"}}
            @body={{htmlSafe
              (i18n
                "chat.edit_category.no_channels_body"
                chatBrowseUrl=(getURL "/chat/browse/open")
              )
            }}
          />
        {{/if}}
      </ConditionalLoadingSpinner>
    </section>
  </template>
}
