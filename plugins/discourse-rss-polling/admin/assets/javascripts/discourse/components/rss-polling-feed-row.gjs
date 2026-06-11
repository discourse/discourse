import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../admin/models/rss-polling-feed-settings";

export default class RssPollingFeedRow extends Component {
  @service dialog;
  @service toasts;

  @cached
  get category() {
    if (!this.args.feed.discourse_category_id) {
      return null;
    }

    return Category.findById(this.args.feed.discourse_category_id);
  }

  @action
  delete() {
    this.dialog.deleteConfirm({
      message: i18n("admin.rss_polling.feeds.confirm_delete"),
      didConfirm: async () => {
        try {
          await RssPollingFeedSettings.deleteFeed(this.args.feed);
          this.args.deleteFeed(this.args.feed);
          this.toasts.success({
            duration: "short",
            data: { message: i18n("admin.rss_polling.feeds.delete_success") },
          });
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    <tr class="d-table__row rss-polling-feed">
      <td class="d-table__cell --overview">
        <LinkTo
          class="d-table__overview-link"
          @route="adminPlugins.show.discourse-rss-polling-feeds.edit"
          @model={{@feed.id}}
        >
          <span
            class="d-table__overview-name rss-polling-feed__url"
          >{{@feed.feed_url}}</span>
        </LinkTo>
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.rss_polling.feed_category_filter"}}
        </div>
        {{@feed.feed_category_filter}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.rss_polling.author"}}
        </div>
        {{#if @feed.user}}
          <span class="rss-polling-feed__author">
            <DUserAvatar @user={{@feed.user}} @size="small" />
            <DUserLink @user={{@feed.user}}>{{@feed.user.username}}</DUserLink>
          </span>
        {{/if}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.rss_polling.discourse_category"}}
        </div>
        {{#if this.category}}
          {{dCategoryBadge this.category link=true}}
        {{/if}}
      </td>
      <td class="d-table__cell --detail">
        <div class="d-table__mobile-label">
          {{i18n "admin.rss_polling.discourse_tags"}}
        </div>
        {{#each @feed.discourse_tags as |tag|}}
          {{dDiscourseTag tag}}
        {{/each}}
      </td>
      <td class="d-table__cell --controls">
        <div class="d-table__cell-actions">
          <DButton
            @route="adminPlugins.show.discourse-rss-polling-feeds.edit"
            @routeModels={{@feed.id}}
            @icon="pencil"
            @title="admin.rss_polling.feeds.edit"
            class="btn-default btn-small rss-polling-feed__edit"
          />
          <DButton
            @action={{this.delete}}
            @icon="trash-can"
            @title="admin.rss_polling.feeds.delete"
            class="btn-default btn-small rss-polling-feed__delete"
          />
        </div>
      </td>
    </tr>
  </template>
}
