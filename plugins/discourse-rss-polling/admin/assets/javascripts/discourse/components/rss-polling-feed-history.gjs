import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";
import RssPollingFeedItemList from "discourse/plugins/discourse-rss-polling/discourse/components/rss-polling-feed-item-list";
import {
  errorMessage,
  pollSummary,
} from "discourse/plugins/discourse-rss-polling/discourse/lib/rss-polling-item";

const VISIBLE_LIMIT = 10;

export default class RssPollingFeedHistory extends Component {
  @tracked openIndex = null;
  @tracked showAll = false;

  @cached
  get attempts() {
    return (this.args.model.poll_attempts ?? []).map((attempt) => ({
      createdAt: attempt.created_at,
      summary: pollSummary(attempt),
      danger: attempt.status === "error",
      items: attempt.items ?? [],
      total:
        attempt.imported_count +
        attempt.updated_count +
        attempt.skipped_count +
        attempt.failed_count,
      errorText: errorMessage(attempt.error),
    }));
  }

  get visibleAttempts() {
    return this.showAll ? this.attempts : this.attempts.slice(0, VISIBLE_LIMIT);
  }

  get hasMore() {
    return !this.showAll && this.attempts.length > VISIBLE_LIMIT;
  }

  get showOlderLabel() {
    return i18n("admin.rss_polling.history.show_older", {
      count: this.attempts.length - VISIBLE_LIMIT,
    });
  }

  @action
  toggle(index) {
    this.openIndex = this.openIndex === index ? null : index;
  }

  @action
  showOlder() {
    this.showAll = true;
  }

  <template>
    <AdminConfigAreaCard
      @heading="admin.rss_polling.history.recent"
      class="rss-polling-feed-history"
    >
      <:content>
        {{#if this.attempts.length}}
          {{#each this.visibleAttempts as |attempt index|}}
            <div
              class="rss-polling-feed-history__attempt
                {{if attempt.danger '--danger'}}"
            >
              <DButton
                @action={{fn this.toggle index}}
                @icon={{if
                  (eq this.openIndex index)
                  "angle-down"
                  "angle-right"
                }}
                class="btn-flat rss-polling-feed-history__summary"
              >
                <span class="rss-polling-feed-history__date">
                  {{dFormatDate attempt.createdAt}}
                </span>
                <span class="rss-polling-feed-history__counts">
                  {{attempt.summary}}
                </span>
              </DButton>

              {{#if (eq this.openIndex index)}}
                {{#if attempt.errorText}}
                  <div class="alert alert-error">{{attempt.errorText}}</div>
                {{/if}}

                {{#if attempt.items.length}}
                  <div class="rss-polling-feed-history__panel">
                    <RssPollingFeedItemList
                      @items={{attempt.items}}
                      @total={{attempt.total}}
                    />
                  </div>
                {{else}}
                  <p class="rss-polling-feed-history__empty">
                    {{i18n "admin.rss_polling.history.no_items"}}
                  </p>
                {{/if}}
              {{/if}}
            </div>
          {{/each}}

          {{#if this.hasMore}}
            <DButton
              @action={{this.showOlder}}
              @translatedLabel={{this.showOlderLabel}}
              class="btn-flat rss-polling-feed-history__more"
            />
          {{/if}}
        {{else}}
          <p class="rss-polling-feed-test__empty">
            {{i18n "admin.rss_polling.history.empty"}}
          </p>
        {{/if}}
      </:content>
    </AdminConfigAreaCard>
  </template>
}
