import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DSelect from "discourse/ui-kit/d-select";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";
import AiLogRow from "discourse/plugins/discourse-ai/discourse/components/ai-log-row";
import AiLogFeatureFilter from "./ai-log-feature-filter";
import AiLogDetailModal from "./modal/ai-log-detail-modal";
import AiLogRetentionModal from "./modal/ai-log-retention-modal";

const MAX_SAFE_ID = Number.MAX_SAFE_INTEGER;
const PERIODS = {
  hour: 1,
  day: 24,
  week: 24 * 7,
};

export default class AiLogs extends Component {
  @service currentUser;
  @service modal;
  @service router;
  @service toasts;

  @tracked logs = [];
  @tracked meta = {};
  @tracked models = [];
  @tracked features = [];
  @tracked loading = false;
  @tracked loadingMore = false;
  @tracked selectedPeriod;
  @tracked selectedOutcome;
  @tracked hasRetries = false;
  @tracked selectedModel;
  @tracked selectedFeature;
  @tracked selectedUsernames = [];
  @tracked unattributed = false;
  @tracked idType = "id";
  @tracked idValue;
  @tracked startDate;
  @tracked endDate;

  _requestId = 0;
  _openRequestId = 0;
  _openLogId;

  constructor() {
    super(...arguments);
    window.addEventListener("popstate", this.syncDetailsFromLocation);
    this.logs = this.args.model.logs || [];
    this.meta = this.args.model.meta || {};
    this.models = this.args.model.models || [];
    this.features = this.mergedFeatures(this.args.model.features, this.logs);
    this.initializeFilters(this.args.queryParams);

    if (this.args.queryParams.details) {
      next(() =>
        this.openDetails(this.args.queryParams.details, { updateUrl: false })
      );
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("popstate", this.syncDetailsFromLocation);
    if (this._openLogId) {
      this.modal.close();
    }
  }

  @action
  syncDetailsFromLocation() {
    const logId = new URL(window.location.href).searchParams.get("details");
    if (logId && String(logId) !== String(this._openLogId)) {
      this.openDetails(logId, { updateUrl: false });
    } else if (!logId && this._openLogId) {
      this._openLogId = undefined;
      this.modal.close();
    }
  }

  mergedFeatures(features = [], logs = []) {
    return [
      ...new Set([
        ...features,
        ...logs.map((log) => log.feature_name).filter(Boolean),
      ]),
    ].sort();
  }

  initializeFilters(params = {}) {
    this.selectedPeriod = params.period || undefined;
    this.selectedOutcome = params.outcome || undefined;
    this.hasRetries =
      params.has_retries === "true" || params.has_retries === true;
    this.selectedModel = params.model ? String(params.model) : undefined;
    this.selectedFeature = params.feature || undefined;
    this.selectedUsernames = params.username ? [params.username] : [];
    this.unattributed =
      params.unattributed === "true" || params.unattributed === true;
    this.idType = params.id_type || "id";
    this.idValue = params.id_value || undefined;
    this.startDate = params.start_date
      ? moment(params.start_date).toDate()
      : moment().subtract(24, "hours").toDate();
    this.endDate = params.end_date
      ? moment(params.end_date).toDate()
      : new Date();
  }

  @cached
  get featureOptions() {
    if (this.selectedFeature && !this.features.includes(this.selectedFeature)) {
      return [...this.features, this.selectedFeature];
    }

    return this.features;
  }

  get periodOptions() {
    return [
      {
        value: "all",
        label: i18n("discourse_ai.logs.all_periods"),
      },
      { value: "hour", label: i18n("discourse_ai.logs.periods.hour") },
      { value: "day", label: i18n("discourse_ai.logs.periods.day") },
      { value: "week", label: i18n("discourse_ai.logs.periods.week") },
      { value: "custom", label: i18n("discourse_ai.logs.periods.custom") },
    ];
  }

  get outcomeOptions() {
    return [
      {
        value: "all",
        label: i18n("discourse_ai.logs.all_outcomes"),
      },
      {
        value: "successful",
        label: i18n("discourse_ai.logs.successful"),
      },
      { value: "failed", label: i18n("discourse_ai.logs.failed") },
    ];
  }

  get idTypeOptions() {
    return [
      { id: "id", name: i18n("discourse_ai.logs.log_id") },
      { id: "topic_id", name: i18n("discourse_ai.logs.topic_id") },
      { id: "post_id", name: i18n("discourse_ai.logs.post_id") },
    ];
  }

  @cached
  get modelOptions() {
    const options = this.models.map((model) => ({
      value: String(model.id),
      label: model.name,
    }));

    if (
      this.selectedModel &&
      !options.some((option) => option.value === this.selectedModel)
    ) {
      options.push({ value: this.selectedModel, label: this.selectedModel });
    }

    return [
      { value: "all", label: i18n("discourse_ai.logs.all_models") },
      ...options,
    ];
  }

  @cached
  get dropdownOptions() {
    return {
      period: this.periodOptions,
      outcome: this.outcomeOptions,
      model: this.modelOptions,
    };
  }

  @cached
  get dropdownValues() {
    return {
      period: this.selectedPeriod || "all",
      outcome: this.selectedOutcome || "all",
      model: this.selectedModel || "all",
    };
  }

  get hasFilters() {
    return Boolean(
      this.selectedPeriod ||
      this.selectedOutcome ||
      this.hasRetries ||
      this.selectedModel ||
      this.selectedFeature ||
      this.selectedUsernames.length ||
      this.unattributed ||
      this.idValue
    );
  }

  get additionalFiltersActive() {
    return Boolean(
      this.hasRetries ||
      this.selectedFeature ||
      this.selectedUsernames.length ||
      this.unattributed ||
      this.idValue
    );
  }

  get requestParams() {
    const params = {
      outcome: this.selectedOutcome || undefined,
      has_retries: this.hasRetries || undefined,
      llm_id: this.selectedModel || undefined,
      feature: this.selectedFeature || undefined,
      username: this.selectedUsernames[0] || undefined,
      unattributed: this.unattributed || undefined,
    };

    if (this.idValue) {
      params[this.idType] = this.idValue;
    }

    if (this.selectedPeriod === "custom") {
      params.start_date = moment(this.startDate).format("YYYY-MM-DD");
      params.end_date = moment(this.endDate).format("YYYY-MM-DD");
      params.timezone =
        this.currentUser?.user_option?.timezone || moment.tz.guess();
    } else if (this.selectedPeriod) {
      params.start_date = moment()
        .subtract(PERIODS[this.selectedPeriod], "hours")
        .toISOString();
      params.end_date = moment().toISOString();
    }

    return params;
  }

  get queryParams() {
    return {
      period: this.selectedPeriod || null,
      start_date:
        this.selectedPeriod === "custom"
          ? moment(this.startDate).format("YYYY-MM-DD")
          : null,
      end_date:
        this.selectedPeriod === "custom"
          ? moment(this.endDate).format("YYYY-MM-DD")
          : null,
      outcome: this.selectedOutcome || null,
      has_retries: this.hasRetries ? "true" : null,
      model: this.selectedModel || null,
      feature: this.selectedFeature || null,
      username: this.selectedUsernames[0] || null,
      unattributed: this.unattributed ? "true" : null,
      id_type: this.idValue ? this.idType : null,
      id_value: this.idValue || null,
    };
  }

  updateUrl(extra = {}) {
    return this.router.transitionTo(this.router.currentRouteName, {
      queryParams: { ...this.queryParams, ...extra },
    });
  }

  updateDetailsUrl(logId, { replace = false } = {}) {
    const url = new URL(window.location.href);
    if (logId) {
      url.searchParams.set("details", logId);
    } else {
      url.searchParams.delete("details");
    }

    const path = `${url.pathname}${url.search}${url.hash}`;
    DiscourseURL[replace ? "replaceState" : "pushState"](path);
  }

  @action
  async refresh() {
    const requestId = ++this._requestId;
    this.loading = true;
    this.loadingMore = false;
    try {
      const result = await ajax("/admin/plugins/discourse-ai/ai-logs.json", {
        data: this.requestParams,
      });
      if (
        requestId !== this._requestId ||
        this.isDestroying ||
        this.isDestroyed
      ) {
        return;
      }

      this.logs = result.logs;
      this.meta = { ...this.meta, ...result.meta };
      this.models = result.models || this.models;
      this.features = this.mergedFeatures(
        result.features || this.features,
        result.logs
      );
      await this.updateUrl();
    } catch (error) {
      if (
        requestId === this._requestId &&
        !this.isDestroying &&
        !this.isDestroyed
      ) {
        popupAjaxError(error);
      }
    } finally {
      if (
        requestId === this._requestId &&
        !this.isDestroying &&
        !this.isDestroyed
      ) {
        this.loading = false;
      }
    }
  }

  @action
  async loadMore() {
    if (!this.meta.has_more || this.loadingMore) {
      return;
    }

    const requestId = this._requestId;
    const cursor = this.meta.next_cursor;
    this.loadingMore = true;
    try {
      const result = await ajax("/admin/plugins/discourse-ai/ai-logs.json", {
        data: { ...this.requestParams, cursor },
      });
      if (
        requestId !== this._requestId ||
        cursor !== this.meta.next_cursor ||
        this.isDestroying ||
        this.isDestroyed
      ) {
        return;
      }

      this.logs = [...this.logs, ...result.logs];
      this.features = this.mergedFeatures(this.features, result.logs);
      this.meta = { ...this.meta, ...result.meta };
    } catch (error) {
      if (
        requestId === this._requestId &&
        !this.isDestroying &&
        !this.isDestroyed
      ) {
        popupAjaxError(error);
      }
    } finally {
      if (
        requestId === this._requestId &&
        !this.isDestroying &&
        !this.isDestroyed
      ) {
        this.loadingMore = false;
      }
    }
  }

  @action
  changeDateRange(value) {
    this.startDate = value.from;
    this.endDate = value.to;
  }

  @action
  changeDropdown(key, value) {
    const selectedValue = value === "all" ? undefined : value;

    if (key === "period") {
      this.selectedPeriod = selectedValue;
      if (this.selectedPeriod && this.selectedPeriod !== "custom") {
        this.endDate = new Date();
        this.startDate = moment()
          .subtract(PERIODS[this.selectedPeriod], "hours")
          .toDate();
      }
    } else if (key === "outcome") {
      this.selectedOutcome = selectedValue;
    } else if (key === "model") {
      this.selectedModel = selectedValue;
    }

    this.refresh();
  }

  @action
  changeFeature(value) {
    this.selectedFeature = value || undefined;
    this.refresh();
  }

  @action
  changeUser(usernames) {
    const selectedUsernames = usernames || [];
    this.selectedUsernames = selectedUsernames;
    this.unattributed = false;
    this.refresh();
  }

  @action
  toggleRetries() {
    this.hasRetries = !this.hasRetries;
    this.refresh();
  }

  @action
  toggleUnattributed() {
    this.unattributed = !this.unattributed;
    if (this.unattributed) {
      this.selectedUsernames = [];
    }
    this.refresh();
  }

  @action
  setIdValue(value) {
    this.idValue = value || undefined;
  }

  @action
  changeIdType(value) {
    this.idType = value;
    if (this.idValue) {
      this.refresh();
    }
  }

  @action
  findById(event) {
    event.preventDefault();
    this.refresh();
  }

  @action
  clearFilters() {
    this.selectedPeriod = undefined;
    this.startDate = moment().subtract(24, "hours").toDate();
    this.endDate = new Date();
    this.selectedOutcome = undefined;
    this.hasRetries = false;
    this.selectedModel = undefined;
    this.selectedFeature = undefined;
    this.selectedUsernames = [];
    this.unattributed = false;
    this.idType = "id";
    this.idValue = undefined;
    return this.refresh();
  }

  @action
  openDetails(logId, { updateUrl = true } = {}) {
    const openLogId = String(logId);
    const openRequestId = ++this._openRequestId;
    this._openLogId = openLogId;
    if (updateUrl) {
      this.updateDetailsUrl(openLogId);
    }

    this.modal.show(AiLogDetailModal, {
      model: {
        logId,
        onClose: () => {
          if (
            this._openRequestId === openRequestId &&
            this._openLogId === openLogId
          ) {
            this._openLogId = undefined;
            this.updateDetailsUrl(null, { replace: true });
          }
        },
      },
    });
  }

  @action
  configureRetention() {
    this.modal.show(AiLogRetentionModal, {
      model: {
        retention: this.meta.retention,
        storage: this.meta.storage,
        onSave: (retention) => {
          this.meta = { ...this.meta, retention };
          this.toasts.success({
            data: { message: i18n("discourse_ai.logs.retention.saved") },
          });
        },
      },
    });
  }

  <template>
    <section class="ai-logs admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "discourse_ai.logs.short_title"}}
        @descriptionLabel={{i18n "discourse_ai.logs.description"}}
      >
        <:actions as |actions|>
          <actions.Primary
            @action={{this.configureRetention}}
            @icon="clock"
            @label="discourse_ai.logs.retention.configure"
          />
          <actions.Default
            @action={{this.refresh}}
            @icon="arrows-rotate"
            @label="discourse_ai.logs.refresh"
          />
        </:actions>
      </DPageSubheader>

      <DFilterControls
        @array={{this.logs}}
        @dropdownOptions={{this.dropdownOptions}}
        @dropdownValue={{this.dropdownValues}}
        @additionalFiltersActive={{this.additionalFiltersActive}}
        @filterDropdownsExpanded={{true}}
        @showDropdownFilterToggle={{false}}
        @showTextFilter={{false}}
        @showNoResults={{false}}
        @loading={{this.loading}}
        @onDropdownFilterChange={{this.changeDropdown}}
        @onResetFilters={{this.clearFilters}}
      >
        <:aboveFilters>
          <h2 class="ai-logs__filters-title">
            {{i18n "discourse_ai.logs.filters.title"}}
          </h2>
        </:aboveFilters>

        <:additionalFilters>
          <fieldset class="ai-logs__feature-filter">
            <legend>{{i18n "discourse_ai.logs.feature"}}</legend>
            <AiLogFeatureFilter
              @valueProperty={{null}}
              @nameProperty={{null}}
              @value={{this.selectedFeature}}
              @content={{this.featureOptions}}
              @onChange={{this.changeFeature}}
              @options={{hash
                translatedNone=(i18n "discourse_ai.logs.all_features")
                translatedFilterPlaceholder=(i18n
                  "discourse_ai.logs.feature_placeholder"
                )
              }}
            />
          </fieldset>

          {{#if (eq this.selectedPeriod "custom")}}
            <fieldset class="ai-logs__date-range-filter">
              <legend>{{i18n "discourse_ai.logs.filters.date_range"}}</legend>
              <DDateTimeInputRange
                @from={{this.startDate}}
                @to={{this.endDate}}
                @showFromTime={{false}}
                @showToTime={{false}}
                @onChange={{this.changeDateRange}}
              />
              <DButton
                class="btn-default"
                @action={{this.refresh}}
                @label="discourse_ai.logs.apply"
              />
            </fieldset>
          {{/if}}

          <fieldset class="ai-logs__user-filter">
            <legend>{{i18n "discourse_ai.logs.user"}}</legend>
            <UserChooser
              @value={{this.selectedUsernames}}
              @onChange={{this.changeUser}}
              @options={{hash
                maximum=1
                none="discourse_ai.logs.user_placeholder"
                filterPlaceholder="discourse_ai.logs.user_placeholder"
                headerAriaLabel=(i18n "discourse_ai.logs.user_placeholder")
              }}
            />
          </fieldset>

          <form class="ai-logs__id-filter" {{on "submit" this.findById}}>
            <label class="ai-logs__id-type">
              <span>{{i18n "discourse_ai.logs.filters.id_type"}}</span>
              <DSelect
                @value={{this.idType}}
                @includeNone={{false}}
                @onChange={{this.changeIdType}}
                as |select|
              >
                {{#each this.idTypeOptions as |idType|}}
                  <select.Option @value={{idType.id}}>
                    {{idType.name}}
                  </select.Option>
                {{/each}}
              </DSelect>
            </label>

            <label class="ai-logs__id-value">
              <span>{{i18n "discourse_ai.logs.filters.id_value"}}</span>
              <input
                type="number"
                min="1"
                max={{MAX_SAFE_ID}}
                placeholder={{i18n "discourse_ai.logs.id_placeholder"}}
                value={{this.idValue}}
                {{on "input" (withEventValue this.setIdValue)}}
              />
            </label>

            <DButton
              type="submit"
              class="btn-default ai-logs__find"
              @label="discourse_ai.logs.find"
            />
          </form>

          <div class="ai-logs__toggles">
            <DToggleSwitch
              @state={{this.hasRetries}}
              @label="discourse_ai.logs.has_retries"
              aria-label={{i18n "discourse_ai.logs.has_retries"}}
              {{on "click" this.toggleRetries}}
            />

            <DToggleSwitch
              @state={{this.unattributed}}
              @label="discourse_ai.logs.unattributed"
              aria-label={{i18n "discourse_ai.logs.unattributed"}}
              {{on "click" this.toggleUnattributed}}
            />
          </div>
        </:additionalFilters>
      </DFilterControls>

      <DConditionalLoadingSpinner @condition={{this.loading}}>
        {{#if this.logs.length}}
          <DLoadMore
            @action={{this.loadMore}}
            @enabled={{this.meta.has_more}}
            @isLoading={{this.loadingMore}}
          >
            <div class="ai-logs__table-wrapper">
              <table class="d-table ai-logs__table">
                <caption class="sr-only">{{i18n
                    "discourse_ai.logs.table_caption"
                  }}</caption>
                <thead class="d-table__header">
                  <tr class="d-table__row">
                    <th class="ai-logs__col-outcome" scope="col"><span
                        class="sr-only"
                      >{{i18n "discourse_ai.logs.outcome"}}</span></th>
                    <th class="ai-logs__col-time" scope="col">{{i18n
                        "discourse_ai.logs.when"
                      }}</th>
                    <th class="ai-logs__col-request" scope="col">{{i18n
                        "discourse_ai.logs.request"
                      }}</th>
                    <th class="ai-logs__col-user" scope="col">{{i18n
                        "discourse_ai.logs.user"
                      }}</th>
                    <th class="ai-logs__col-duration" scope="col">
                      <span class="ai-logs__duration-heading">{{i18n
                          "discourse_ai.logs.duration"
                        }}</span>
                      <span class="ai-logs__tokens-heading">{{i18n
                          "discourse_ai.logs.tokens_direction"
                        }}</span>
                    </th>
                    <th class="ai-logs__col-context" scope="col">{{i18n
                        "discourse_ai.logs.context"
                      }}</th>
                    <th class="ai-logs__col-actions" scope="col"><span
                        class="sr-only"
                      >{{i18n "discourse_ai.logs.actions"}}</span></th>
                  </tr>
                </thead>
                <tbody>
                  {{#each this.logs as |currentLog|}}
                    <AiLogRow
                      @log={{currentLog}}
                      @onOpen={{this.openDetails}}
                    />
                  {{/each}}
                </tbody>
              </table>
            </div>
          </DLoadMore>
        {{else}}
          <div class="ai-logs__empty">
            <p>{{if
                this.hasFilters
                (i18n "discourse_ai.logs.no_results")
                (i18n "discourse_ai.logs.no_logs")
              }}</p>
          </div>
        {{/if}}
      </DConditionalLoadingSpinner>
    </section>
  </template>
}
