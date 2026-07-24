import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
const KEEP_LIMIT = 20;

export default class RssPollingFeedHistory extends Component {
  @service messageBus;

  @tracked openId = null;
  @tracked showAll = false;
  @tracked rawAttempts;

  constructor() {
    super(...arguments);
    this.rawAttempts = this.args.model.poll_attempts ?? [];
    this.messageBus.subscribe(
      this.channel,
      this.onAttempt,
      this.args.model.last_message_id
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.channel, this.onAttempt);
  }

  get channel() {
    return `/rss-polling/feeds/${this.args.model.id}`;
  }

  @action
  onAttempt(attempt) {
    if (this.rawAttempts.some((existing) => existing.id === attempt.id)) {
      return;
    }

    this.rawAttempts = [attempt, ...this.rawAttempts].slice(0, KEEP_LIMIT);
  }

  @cached
  get attempts() {
    return this.rawAttempts.map((attempt) => ({
      id: attempt.id,
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
  toggle(id) {
    this.openId = this.openId === id ? null : id;
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
          <table class="d-table rss-polling-feed-history__table">
            <tbody class="d-table__body">
              {{#each this.visibleAttempts as |attempt|}}
                <tr
                  class="d-table__row rss-polling-feed-history__attempt
                    {{if attempt.danger '--danger'}}"
                >
                  <td class="d-table__cell --overview">
                    <DButton
                      @action={{fn this.toggle attempt.id}}
                      @icon={{if
                        (eq this.openId attempt.id)
                        "angle-down"
                        "angle-right"
                      }}
                      @ariaExpanded={{eq this.openId attempt.id}}
                      @ariaLabel={{attempt.summary}}
                      @translatedLabel={{attempt.summary}}
                      class="btn-flat rss-polling-feed-history__summary"
                    >
                      <span class="rss-polling-feed-history__date">
                        {{dFormatDate attempt.createdAt}}
                      </span>
                    </DButton>
                  </td>
                  <td class="d-table__cell --detail">
                    <span class="rss-polling-feed-history__counts">
                      {{attempt.summary}}
                    </span>
                  </td>
                </tr>

                {{#if (eq this.openId attempt.id)}}
                  <tr class="d-table__row rss-polling-feed-history__detail">
                    <td class="d-table__cell" colspan="2">
                      {{#if attempt.errorText}}
                        <div class="alert alert-error">
                          {{attempt.errorText}}
                        </div>
                      {{/if}}

                      {{#if attempt.items.length}}
                        <RssPollingFeedItemList
                          @items={{attempt.items}}
                          @total={{attempt.total}}
                        />
                      {{else}}
                        <p class="rss-polling-feed-history__empty">
                          {{i18n "admin.rss_polling.history.no_items"}}
                        </p>
                      {{/if}}
                    </td>
                  </tr>
                {{/if}}
              {{/each}}
            </tbody>
          </table>

          {{#if this.hasMore}}
            <DButton
              @action={{this.showOlder}}
              @translatedLabel={{this.showOlderLabel}}
              class="btn-flat rss-polling-feed-history__more"
            />
          {{/if}}
        {{else}}
          <p class="rss-polling-feed-history__empty">
            {{i18n "admin.rss_polling.history.empty"}}
          </p>
        {{/if}}
      </:content>
    </AdminConfigAreaCard>
  </template>
}
