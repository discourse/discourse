import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import EmptyState from "discourse/components/empty-state";
import categoryBadge from "discourse/helpers/category-badge";
import icon from "discourse/helpers/d-icon";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function channelColorStyle(channel) {
  return htmlSafe(`color: #${channel.chatable?.color || "000"}`);
}

function channelIcon(channel) {
  return channel.emoji ? replaceEmoji(`:${channel.emoji}:`) : icon("d-chat");
}

function isSubcategoryChannel(channel, categoryId) {
  return channel.chatable?.id !== categoryId;
}

export default class EditCategoryChat extends Component {
  @tracked channels = null;
  @tracked loading = true;
  @tracked showSubcategoryChannels = true;

  get categoryChannels() {
    return (this.channels || []).filter(
      (c) => !isSubcategoryChannel(c, this.args.category.id)
    );
  }

  get subcategoryChannels() {
    return (this.channels || []).filter((c) =>
      isSubcategoryChannel(c, this.args.category.id)
    );
  }

  get hasSubcategoryChannels() {
    return this.subcategoryChannels.length > 0;
  }

  get displayedChannels() {
    if (this.showSubcategoryChannels) {
      return this.channels || [];
    }
    return this.categoryChannels;
  }

  @action
  toggleSubcategoryChannels() {
    this.showSubcategoryChannels = !this.showSubcategoryChannels;
  }

  @action
  async loadChannels() {
    try {
      this.loading = true;
      const result = await ajax(
        `/chat/api/channels?chatable_id=${this.args.category.id}&chatable_type=Category&include_subcategories=true`
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
        {{#if this.displayedChannels.length}}
          {{#if this.hasSubcategoryChannels}}
            <div class="edit-category-chat__subcategory-toggle">
              <DToggleSwitch
                @state={{this.showSubcategoryChannels}}
                {{on "click" this.toggleSubcategoryChannels}}
              />
              <span>{{i18n "chat.edit_category.include_subcategories"}}</span>
            </div>
          {{/if}}
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
              {{#each this.displayedChannels as |channel|}}
                <tr class="d-table__row" data-channel-id={{channel.id}}>
                  <td class="d-table__cell edit-category-chat__channel-name">
                    <span
                      class="chat-channel-icon --icon"
                      style={{channelColorStyle channel}}
                    >
                      {{channelIcon channel}}
                    </span>
                    <span>{{channel.title}}</span>
                    {{#if (isSubcategoryChannel channel @category.id)}}
                      <div>
                        {{categoryBadge channel.chatable link=true}}
                      </div>
                    {{/if}}
                  </td>
                  <td
                    class="d-table__cell edit-category-chat__channel-description"
                  >
                    {{if channel.description channel.description "-"}}
                  </td>
                  <td
                    class="d-table__cell edit-category-chat__channel-actions d-table__cell-actions"
                  >
                    <LinkTo
                      @route="chat.channel.info.settings"
                      @models={{array (or channel.slug "-") channel.id}}
                      class="btn btn-default btn-small"
                    >
                      {{i18n "chat.edit_category.settings"}}
                    </LinkTo>
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
