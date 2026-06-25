import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { FeedEnabledToggle } from "discourse/plugins/discourse-rss-polling/discourse/lib/rss-polling-item";
import RssPollingFeedSettings from "../../admin/models/rss-polling-feed-settings";

export default class RssPollingFeedRow extends Component {
  @service dialog;
  @service toasts;

  constructor() {
    super(...arguments);
    this.feedToggle = new FeedEnabledToggle(this.args.feed, this.toasts);
  }

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
    <tr
      class="d-table__row rss-polling-feed
        {{unless this.feedToggle.enabled 'is-disabled'}}"
    >
      <td class="d-table__cell --overview">
        <LinkTo
          class="d-table__overview-link"
          @route="adminPlugins.show.discourse-rss-polling-feeds.edit"
          @model={{@feed.id}}
        >
          <span
            class="d-table__overview-name rss-polling-feed__url"
          >{{@feed.redacted_feed_url}}</span>
        </LinkTo>

        <div class="rss-polling-feed__meta">
          <span class="rss-polling-feed__author">
            <span class="d-table__mobile-label">{{i18n
                "admin.rss_polling.author"
              }}</span>
            <DUserAvatar @user={{@feed.author}} @size="small" />
            <DUserLink
              @user={{@feed.author}}
            >{{@feed.author.username}}</DUserLink>
          </span>
          {{#if this.category}}
            <span class="rss-polling-feed__category">
              <span class="d-table__mobile-label">{{i18n
                  "admin.rss_polling.discourse_category"
                }}</span>
              {{dCategoryBadge this.category link=true}}
            </span>
          {{/if}}
          {{#if @feed.discourse_tags.length}}
            <span class="rss-polling-feed__tags">
              <span class="d-table__mobile-label">{{i18n
                  "admin.rss_polling.discourse_tags"
                }}</span>
              {{#each @feed.discourse_tags as |tag|}}
                {{dDiscourseTag tag}}
              {{/each}}
            </span>
          {{/if}}
          {{#if @feed.feed_category_filter}}
            <span
              class="rss-polling-feed__filter"
              title={{i18n "admin.rss_polling.feed_category_filter"}}
            >
              <span class="d-table__mobile-label">{{i18n
                  "admin.rss_polling.feed_category_filter"
                }}</span>
              {{icon "filter"}}
              {{@feed.feed_category_filter}}
            </span>
          {{/if}}
        </div>
      </td>
      <td class="d-table__cell rss-polling-feed__status">
        <DToggleSwitch
          @state={{this.feedToggle.enabled}}
          title={{if
            this.feedToggle.enabled
            (i18n "admin.rss_polling.feeds.disable")
            (i18n "admin.rss_polling.feeds.enable")
          }}
          class="rss-polling-feed__toggle"
          {{on "click" this.feedToggle.toggle}}
        />
        <span class="d-table__mobile-label">{{if
            this.feedToggle.enabled
            (i18n "admin.rss_polling.status.enabled")
            (i18n "admin.rss_polling.status.disabled")
          }}</span>
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
            class="btn-danger btn-small rss-polling-feed__delete"
          />
        </div>
      </td>
    </tr>
  </template>
}
