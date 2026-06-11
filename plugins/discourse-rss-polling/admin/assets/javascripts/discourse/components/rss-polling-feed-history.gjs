import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";
import RssPollingFeedItemList from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-item-list";
import { errorMessage } from "discourse/plugins/discourse-rss-polling/discourse/lib/rss-polling-item";

export default class RssPollingFeedHistory extends Component {
  @cached
  get attempts() {
    return (this.args.model.poll_attempts ?? []).map((attempt) => ({
      createdAt: attempt.created_at,
      summary: this.summaryFor(attempt),
      items: attempt.items ?? [],
      total:
        attempt.imported_count +
        attempt.updated_count +
        attempt.skipped_count +
        attempt.failed_count,
      errorText: errorMessage(attempt.error),
    }));
  }

  summaryFor(attempt) {
    const counts = ["imported", "updated", "skipped", "failed"];
    const parts = counts
      .filter((name) => attempt[`${name}_count`] > 0)
      .map((name) =>
        i18n(`admin.rss_polling.history.${name}_count`, {
          count: attempt[`${name}_count`],
        })
      );

    return parts.length
      ? parts.join(" · ")
      : i18n("admin.rss_polling.history.no_changes");
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-rss-polling-feeds"
      @label="admin.rss_polling.feeds.back"
    />
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content rss-polling-feed-history">
        <AdminConfigAreaCard @translatedHeading={{@model.feed_url}}>
          <:content>
            {{#if this.attempts.length}}
              {{#each this.attempts as |attempt|}}
                <details class="rss-polling-feed-history__attempt">
                  <summary class="rss-polling-feed-history__summary">
                    <span class="rss-polling-feed-history__date">
                      {{dFormatDate attempt.createdAt}}
                    </span>
                    <span class="rss-polling-feed-history__counts">
                      {{attempt.summary}}
                    </span>
                  </summary>

                  {{#if attempt.errorText}}
                    <div class="alert alert-error">{{attempt.errorText}}</div>
                  {{/if}}

                  {{#if attempt.items.length}}
                    <RssPollingFeedItemList
                      @items={{attempt.items}}
                      @total={{attempt.total}}
                    />
                  {{else}}
                    <p class="rss-polling-feed-test__empty">
                      {{i18n "admin.rss_polling.history.no_items"}}
                    </p>
                  {{/if}}
                </details>
              {{/each}}
            {{else}}
              <p class="rss-polling-feed-test__empty">
                {{i18n "admin.rss_polling.history.empty"}}
              </p>
            {{/if}}
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
