import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { underscore } from "@ember/string";
import { actionModalClassMap } from "discourse/components/reviewable/item";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const PENDING = "pending";
const APPLYING = "applying";
const APPLIED = "applied";
const FAILED = "failed";
const HANDLED = "handled";

class Row {
  @tracked error;
  @tracked selected;
  @tracked status = PENDING;

  constructor(suggestion) {
    this.suggestion = suggestion;
    this.blockedReason =
      suggestion.blocked_reason ||
      (actionModalClassMap[suggestion.action.server_action] && "needs_input");
    this.selected = !this.blockedReason;
  }

  get selectable() {
    return (
      !this.blockedReason && (this.status === PENDING || this.status === FAILED)
    );
  }

  get checked() {
    return this.selectable && this.selected;
  }

  get typeLabel() {
    return i18n(`review.types.${underscore(this.suggestion.type)}.title`, {
      defaultValue: this.suggestion.type,
    });
  }

  get reasons() {
    return this.suggestion.reasons.join(", ");
  }

  get confidence() {
    return i18n("discourse_ai.review_bulk.confidence", {
      percent: Math.floor(this.suggestion.confidence * 100),
    });
  }

  get statusLabel() {
    if (this.status === FAILED) {
      return this.error;
    }

    if (this.status !== PENDING) {
      return i18n(`discourse_ai.review_bulk.status.${this.status}`);
    }

    if (this.blockedReason) {
      return i18n(`discourse_ai.review_bulk.blocked.${this.blockedReason}`);
    }
  }
}

export default class AiReviewBulk extends Component {
  @service currentUser;
  @service dialog;
  @service router;

  @tracked applying = false;
  @tracked loadingMore = false;
  @tracked more;

  @cached
  get initialRows() {
    return this.args.suggestions.map((suggestion) => new Row(suggestion));
  }

  get rows() {
    return this.more
      ? [...this.initialRows, ...this.more.rows]
      : this.initialRows;
  }

  get nextOffset() {
    return this.more ? this.more.nextOffset : this.args.nextOffset;
  }

  get selectableRows() {
    return this.rows.filter((row) => row.selectable);
  }

  get selectedRows() {
    return this.rows.filter((row) => row.checked);
  }

  get allSelected() {
    return (
      this.selectableRows.length > 0 &&
      this.selectedRows.length === this.selectableRows.length
    );
  }

  get applyDisabled() {
    return this.applying || this.selectedRows.length === 0;
  }

  get busy() {
    return this.applying || this.loadingMore;
  }

  @action
  toggleAll(event) {
    const { checked } = event.target;
    this.selectableRows.forEach((row) => (row.selected = checked));
  }

  @action
  toggle(row, event) {
    row.selected = event.target.checked;
  }

  @action
  confirmApply() {
    const rows = this.selectedRows;
    const destructive = rows.filter(
      (row) => row.suggestion.action.destructive
    ).length;
    const options = {
      message: i18n(
        destructive > 0
          ? "discourse_ai.review_bulk.confirm_destructive"
          : "discourse_ai.review_bulk.confirm",
        { count: rows.length, destructive }
      ),
      didConfirm: () => this.#apply(rows),
    };

    if (destructive > 0) {
      this.dialog.deleteConfirm(options);
    } else {
      this.dialog.confirm(options);
    }
  }

  @action
  refresh() {
    this.more = null;
    this.router.refresh("review.bulk");
  }

  @action
  async loadMore() {
    this.loadingMore = true;

    try {
      // Applied and handled rows have left the pending list the offset counts.
      const resolved = this.rows.filter((row) =>
        [APPLIED, HANDLED].includes(row.status)
      ).length;
      const result = await ajax("/review/bulk.json", {
        data: { offset: Math.max(this.nextOffset - resolved, 0) },
      });
      const known = new Set(this.rows.map((row) => row.suggestion.id));
      const rows = result.suggestions
        .filter((suggestion) => !known.has(suggestion.id))
        .map((suggestion) => new Row(suggestion));

      this.more = {
        rows: [...(this.more?.rows || []), ...rows],
        nextOffset: result.next_offset && result.next_offset + resolved,
      };
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loadingMore = false;
    }
  }

  async #apply(rows) {
    this.applying = true;

    try {
      for (const row of rows) {
        if (this.isDestroying) {
          return;
        }

        // An earlier action in this run can resolve later items too.
        if (row.status === PENDING || row.status === FAILED) {
          await this.#applyRow(row);
        }
      }
    } finally {
      this.applying = false;
    }
  }

  async #applyRow(row) {
    const { id, version, action: suggested } = row.suggestion;
    row.status = APPLYING;

    try {
      const { reviewable_perform_result: result } = await ajax(
        `/review/${id}/perform/${suggested.server_action}?version=${version}`,
        { type: "PUT" }
      );
      row.status = APPLIED;
      this.#markHandled(row, result);

      if (result.reviewable_count !== undefined) {
        this.currentUser.updateReviewableCount(result.reviewable_count);
      }
    } catch (error) {
      row.error = extractError(error);
      row.status = FAILED;
    }
  }

  #markHandled(appliedRow, result) {
    const ids = new Set([
      ...(result.remove_reviewable_ids || []),
      ...Object.keys(result.reviewable_updates || {}).map(Number),
    ]);

    this.rows.forEach((row) => {
      if (row !== appliedRow && ids.has(row.suggestion.id) && row.selectable) {
        row.status = HANDLED;
      }
    });
  }

  <template>
    <div class="ai-review-bulk">
      {{#if this.rows.length}}
        <div class="ai-review-bulk__header">
          <p class="ai-review-bulk__description">
            {{i18n "discourse_ai.review_bulk.description"}}
          </p>
          <div class="ai-review-bulk__controls">
            <DButton
              class="btn-default ai-review-bulk__refresh"
              @action={{this.refresh}}
              @disabled={{this.busy}}
              @icon="arrows-rotate"
              @label="discourse_ai.review_bulk.refresh"
            />
            <DButton
              class="btn-primary ai-review-bulk__apply"
              @action={{this.confirmApply}}
              @disabled={{this.applyDisabled}}
              @icon="discourse-sparkles"
              @isLoading={{this.applying}}
              @translatedLabel={{i18n
                "discourse_ai.review_bulk.apply"
                count=this.selectedRows.length
              }}
            />
          </div>
        </div>

        <table class="d-table ai-review-bulk__table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell ai-review-bulk__select">
                <input
                  aria-label={{i18n "discourse_ai.review_bulk.select_all"}}
                  checked={{this.allSelected}}
                  class="ai-review-bulk__select-all"
                  disabled={{this.applying}}
                  type="checkbox"
                  {{on "change" this.toggleAll}}
                />
              </th>
              <th class="d-table__header-cell">
                {{i18n "discourse_ai.review_bulk.columns.item"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "discourse_ai.review_bulk.columns.user"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "discourse_ai.review_bulk.columns.reason"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "discourse_ai.review_bulk.columns.created"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "discourse_ai.review_bulk.columns.action"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "discourse_ai.review_bulk.columns.status"}}
              </th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each this.rows as |row|}}
              <tr
                class={{dConcatClass
                  "d-table__row"
                  "ai-review-bulk__row"
                  (concat "--" row.status)
                  (if row.blockedReason "--blocked")
                }}
                data-reviewable-id={{row.suggestion.id}}
              >
                <td class="d-table__cell ai-review-bulk__select">
                  <input
                    aria-label={{i18n
                      "discourse_ai.review_bulk.select_item"
                      id=row.suggestion.id
                    }}
                    checked={{row.checked}}
                    class="ai-review-bulk__checkbox"
                    disabled={{or this.applying (not row.selectable)}}
                    type="checkbox"
                    {{on "change" (fn this.toggle row)}}
                  />
                </td>
                <td class="d-table__cell ai-review-bulk__item">
                  <div class="ai-review-bulk__title">
                    <span class="ai-review-bulk__type">{{row.typeLabel}}</span>
                    <LinkTo @model={{row.suggestion.id}} @route="review.show">
                      {{#if row.suggestion.title}}
                        {{row.suggestion.title}}
                      {{else}}
                        {{i18n
                          "discourse_ai.review_bulk.untitled"
                          id=row.suggestion.id
                        }}
                      {{/if}}
                    </LinkTo>
                  </div>
                  {{#if row.suggestion.excerpt}}
                    <div
                      class="ai-review-bulk__excerpt"
                      title={{row.suggestion.excerpt}}
                    >{{row.suggestion.excerpt}}</div>
                  {{/if}}
                </td>
                <td class="d-table__cell ai-review-bulk__user">
                  {{row.suggestion.username}}
                </td>
                <td class="d-table__cell ai-review-bulk__reason">
                  {{row.reasons}}
                </td>
                <td class="d-table__cell ai-review-bulk__created">
                  {{dAgeWithTooltip row.suggestion.created_at}}
                </td>
                <td class="d-table__cell ai-review-bulk__action">
                  <span
                    class={{dConcatClass
                      "ai-review-bulk__action-label"
                      (if row.suggestion.action.destructive "--destructive")
                    }}
                  >{{row.suggestion.action.label}}</span>
                  <span class="ai-review-bulk__confidence">
                    {{row.confidence}}
                  </span>
                </td>
                <td class="d-table__cell ai-review-bulk__status">
                  {{#if row.blockedReason}}
                    <DTooltip @content={{row.statusLabel}}>
                      <:trigger>
                        <LinkTo
                          aria-label={{row.statusLabel}}
                          class="ai-review-bulk__open"
                          @model={{row.suggestion.id}}
                          @route="review.show"
                        >{{dIcon "up-right-from-square"}}</LinkTo>
                      </:trigger>
                    </DTooltip>
                  {{else}}
                    {{row.statusLabel}}
                  {{/if}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>

        {{#if this.nextOffset}}
          <DButton
            class="btn-default ai-review-bulk__load-more"
            @action={{this.loadMore}}
            @disabled={{this.busy}}
            @isLoading={{this.loadingMore}}
            @label="discourse_ai.review_bulk.load_more"
          />
        {{/if}}
      {{else}}
        <div class="no-review ai-review-bulk__empty">
          {{dIcon "discourse-sparkles"}}
          {{i18n "discourse_ai.review_bulk.none"}}
        </div>
      {{/if}}
    </div>
  </template>
}
