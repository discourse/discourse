import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import UserAutocompleteResults from "discourse/components/user-autocomplete-results";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import KeyValueStore from "discourse/lib/key-value-store";
import { TextareaAutocompleteHandler } from "discourse/lib/textarea-text-manipulation";
import DiscourseURL from "discourse/lib/url";
import userSearch, { validateSearchResult } from "discourse/lib/user-search";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DCountI18n from "discourse/ui-kit/d-count-i18n";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import dAutocomplete from "discourse/ui-kit/modifiers/d-autocomplete";
import { i18n } from "discourse-i18n";
import AiLogRow from "discourse/plugins/discourse-ai/discourse/components/ai-log-row";
import { newLogsPollIntervalMs } from "../lib/ai-logs-poll-interval";
import AiLogFeatureFilter from "./ai-log-feature-filter";
import AiLogDetailModal from "./modal/ai-log-detail-modal";
import AiLogRetentionModal from "./modal/ai-log-retention-modal";

const ALL_FILTER_VALUE = "__all__";
const CUSTOM_DEFAULT_DAYS = 30;
const MAX_SEARCH_LENGTH = 200;
const PERIODS = {
  hour: 1,
  day: 24,
  week: 24 * 7,
};

export default class AiLogs extends Component {
  @service currentUser;
  @service modal;
  @service router;
  @service siteSettings;
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
  @tracked searchText = "";
  @tracked unattributed = false;
  @tracked startDate;
  @tracked endDate;
  @tracked newLogsCount = 0;
  @tracked loadingNewLogs = false;
  keyValueStore = new KeyValueStore("discourse-ai-logs");

  _requestId = 0;
  _openRequestId = 0;
  _openLogId;
  _autocompleteCleanups = [];
  _pollTimer;
  _pollInFlight = false;
  _pollEpoch = 0;
  _emptyPolls = 0;
  _sinceId = 0;

  constructor() {
    super(...arguments);
    window.addEventListener("popstate", this.syncDetailsFromLocation);
    document.addEventListener("visibilitychange", this.onVisibilityChange);
    this.logs = this.args.model.logs || [];
    this.meta = this.args.model.meta || {};
    this.captureNewLogsBaseline();
    this.models = this.args.model.models || [];
    this.features = this.mergedFeatures(this.args.model.features, this.logs);
    this.initializeFilters(this.args.queryParams);
    this.schedulePoll();

    if (this.args.queryParams.details) {
      next(() =>
        this.openDetails(this.args.queryParams.details, { updateUrl: false })
      );
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("popstate", this.syncDetailsFromLocation);
    document.removeEventListener("visibilitychange", this.onVisibilityChange);
    clearTimeout(this._pollTimer);
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
    this.searchText = params.search || "";
    this.unattributed =
      params.unattributed === "true" || params.unattributed === true;
    this.startDate = params.start_date
      ? moment(params.start_date).toDate()
      : moment().subtract(CUSTOM_DEFAULT_DAYS, "days").toDate();
    this.endDate = params.end_date
      ? moment(params.end_date).toDate()
      : new Date();
  }

  get periodOptions() {
    return [
      { id: "hour", name: i18n("discourse_ai.logs.periods.hour") },
      { id: "day", name: i18n("discourse_ai.logs.periods.day") },
      { id: "week", name: i18n("discourse_ai.logs.periods.week") },
      { id: "custom", name: i18n("discourse_ai.logs.periods.custom") },
    ];
  }

  get outcomeOptions() {
    return [
      {
        value: ALL_FILTER_VALUE,
        label: i18n("discourse_ai.logs.all_outcomes"),
      },
      {
        value: "successful",
        label: i18n("discourse_ai.logs.successful"),
      },
      { value: "failed", label: i18n("discourse_ai.logs.failed") },
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
      { value: ALL_FILTER_VALUE, label: i18n("discourse_ai.logs.all_models") },
      ...options,
    ];
  }

  @cached
  get featureOptions() {
    if (this.selectedFeature && !this.features.includes(this.selectedFeature)) {
      return [...this.features, this.selectedFeature];
    }

    return this.features;
  }

  @cached
  get dropdownOptions() {
    return {
      outcome: this.outcomeOptions,
      model: this.modelOptions,
    };
  }

  @cached
  get dropdownValues() {
    return {
      outcome: this.selectedOutcome || ALL_FILTER_VALUE,
      model: this.selectedModel || ALL_FILTER_VALUE,
    };
  }

  @cached
  get defaultDropdownValues() {
    return {
      outcome: ALL_FILTER_VALUE,
      model: ALL_FILTER_VALUE,
    };
  }

  get rememberedDrawerExpanded() {
    return this.keyValueStore.get("filter_drawer") !== "collapsed";
  }

  @action
  persistDrawerState(expanded) {
    this.keyValueStore.set({
      key: "filter_drawer",
      value: expanded ? "expanded" : "collapsed",
    });
  }

  get additionalFiltersActive() {
    return Boolean(
      this.selectedFeature || this.hasRetries || this.unattributed
    );
  }

  get hasActiveDrawerFilters() {
    return Boolean(
      this.selectedOutcome || this.selectedModel || this.additionalFiltersActive
    );
  }

  get hasFilters() {
    return Boolean(
      this.selectedPeriod ||
      this.selectedOutcome ||
      this.hasRetries ||
      this.selectedModel ||
      this.selectedFeature ||
      this.searchText ||
      this.unattributed
    );
  }

  get requestParams() {
    const search = this.searchText.trim().slice(0, MAX_SEARCH_LENGTH);
    const params = {
      outcome: this.selectedOutcome || undefined,
      has_retries: this.hasRetries || undefined,
      llm_id: this.selectedModel || undefined,
      feature: this.selectedFeature || undefined,
      unattributed: this.unattributed || undefined,
    };

    if (search) {
      params.search = search;
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
      search: this.searchText.trim() || null,
      unattributed: this.unattributed ? "true" : null,
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
  async refresh({ focusFilters = false, quiet = false, skipUrl = false } = {}) {
    const requestId = ++this._requestId;
    if (!quiet) {
      this.loading = true;
    }
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
      this.captureNewLogsBaseline();
      this.models = result.models || this.models;
      this.features = this.mergedFeatures(
        result.features || this.features,
        result.logs
      );
      // a fresh list supersedes any in-flight new-log poll and clears the banner
      this._pollEpoch++;
      this.newLogsCount = 0;
      this._emptyPolls = 0;
      if (!skipUrl) {
        await this.updateUrl();
        if (focusFilters) {
          next(() =>
            document
              .querySelector(
                ".ai-logs .d-filter-controls__input, .ai-logs .d-filter-controls__toggle-filters"
              )
              ?.focus()
          );
        }
      }
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
        if (!quiet) {
          this.loading = false;
        }
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

  get hasNewLogs() {
    return this.newLogsCount > 0;
  }

  // an empty filtered list has no newest row to poll against, so fall back to
  // the table's high-water mark — otherwise every row would count as new
  captureNewLogsBaseline() {
    this._sinceId = this.logs[0]?.id || this.meta.max_id || 0;
  }

  get pollIntervalMs() {
    return newLogsPollIntervalMs(this._emptyPolls);
  }

  schedulePoll() {
    clearTimeout(this._pollTimer);
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this._pollTimer = setTimeout(
      () => this.pollForNewLogs(),
      this.pollIntervalMs
    );
  }

  @action
  onVisibilityChange() {
    if (document.visibilityState === "visible") {
      // returning to the tab refreshes the banner immediately
      this.pollForNewLogs();
    }
  }

  @action
  async pollForNewLogs() {
    clearTimeout(this._pollTimer);
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (
      this._openLogId ||
      document.visibilityState === "hidden" ||
      this.loading ||
      this.loadingMore ||
      this._pollInFlight
    ) {
      this.schedulePoll();
      return;
    }

    const epoch = this._pollEpoch;
    this._pollInFlight = true;
    try {
      const result = await ajax(
        "/admin/plugins/discourse-ai/ai-logs/new.json",
        {
          data: { ...this.requestParams, since_id: this._sinceId },
        }
      );
      if (this.isDestroying || this.isDestroyed || epoch !== this._pollEpoch) {
        return;
      }
      if (result.new_logs_count !== undefined) {
        this.newLogsCount = result.new_logs_count;
        // back off while the list is quiet; snap back the moment something
        // arrives so the next wave is noticed without delay
        this._emptyPolls = result.new_logs_count > 0 ? 0 : this._emptyPolls + 1;
      }
    } catch {
      // transient failures are expected while offline; the next tick retries
    } finally {
      this._pollInFlight = false;
      this.schedulePoll();
    }
  }

  @action
  async showIncomingLogs(event) {
    event?.preventDefault();
    if (this.loadingNewLogs) {
      return;
    }
    this.loadingNewLogs = true;
    try {
      await this.refresh({ quiet: true });
    } finally {
      this.loadingNewLogs = false;
    }
  }

  @action
  selectPeriod(period) {
    this.selectedPeriod = this.selectedPeriod === period ? undefined : period;
    if (this.selectedPeriod) {
      this.endDate = new Date();
      this.startDate =
        this.selectedPeriod === "custom"
          ? moment().subtract(CUSTOM_DEFAULT_DAYS, "days").toDate()
          : moment().subtract(PERIODS[this.selectedPeriod], "hours").toDate();
    }
    this.refresh();
  }

  @action
  changeDateRange(value) {
    this.startDate = value.from;
    this.endDate = value.to;
  }

  @action
  changeDropdown(key, value) {
    const selectedValue = value === ALL_FILTER_VALUE ? undefined : value;

    if (key === "outcome") {
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
  onTextFilterChange(event) {
    // keep the live-search state in sync with the server's 200-char cap so a
    // long paste surfaces as a truncation instead of a 400 error
    this.searchText = (event.target.value || "").slice(0, MAX_SEARCH_LENGTH);
    discourseDebounce(this, this.performLiveSearch, {}, INPUT_DELAY);
  }

  async performLiveSearch() {
    // Update the URL via replaceState (not a router transition) so typing is
    // never interrupted by the focus churn a transition causes — a keystroke
    // landing on <body> in that window would be silently dropped.
    const url = new URL(window.location.href);
    const search = this.searchText.trim();
    if (search) {
      url.searchParams.set("search", search);
    } else {
      url.searchParams.delete("search");
    }
    // URLSearchParams encodes spaces as "+"; emit %20 to match router URLs
    url.search = url.search.replace(/\+/g, "%20");
    DiscourseURL.replaceState(`${url.pathname}${url.search}${url.hash}`);
    await this.refresh({ quiet: true, skipUrl: true });
  }

  @action
  attachUserAutocomplete(element) {
    if (!this.siteSettings.enable_mentions) {
      return;
    }

    const input = element.querySelector(".d-filter-controls__input");
    if (!input || this._autocompleteCleanups.length) {
      return;
    }

    const handler = new TextareaAutocompleteHandler(input);
    const modifiers = [
      dAutocomplete.setupAutocomplete(getOwner(this), input, handler, {
        component: UserAutocompleteResults,
        key: UserAutocompleteResults.TRIGGER_KEY,
        autoSelectFirstSuggestion: false,
        transformComplete: (result) => {
          validateSearchResult(result);
          return result.username || result.name;
        },
        dataSource: (term) =>
          term.includes(" ") || term.trim().length < 2
            ? []
            : userSearch({ term }),
        fixedTextareaPosition: true,
        offset: 2,
      }),
    ];

    this._autocompleteCleanups.push(() =>
      modifiers.forEach((modifier) => modifier.cleanup())
    );
  }

  @action
  teardownUserAutocomplete() {
    this._autocompleteCleanups.forEach((cleanup) => cleanup());
    this._autocompleteCleanups = [];
  }

  @action
  toggleRetries() {
    this.hasRetries = !this.hasRetries;
    this.refresh();
  }

  @action
  toggleUnattributed() {
    this.unattributed = !this.unattributed;
    this.refresh();
  }

  @action
  clearFilters() {
    this.selectedPeriod = undefined;
    this.startDate = moment().subtract(CUSTOM_DEFAULT_DAYS, "days").toDate();
    this.endDate = new Date();
    this.selectedOutcome = undefined;
    this.selectedModel = undefined;
    this.selectedFeature = undefined;
    this.searchText = "";
    this.hasRetries = false;
    this.unattributed = false;
    this.refresh({ focusFilters: true });
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
    <section
      class="ai-logs admin-detail"
      {{didInsert this.attachUserAutocomplete}}
      {{willDestroy this.teardownUserAutocomplete}}
    >
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

      <div
        class="ai-logs__filters
          {{if this.hasActiveDrawerFilters 'ai-logs__filters--drawer-active'}}"
      >
        <DFilterControls
          @array={{this.logs}}
          @dropdownOptions={{this.dropdownOptions}}
          @dropdownValue={{this.dropdownValues}}
          @defaultDropdownValue={{this.defaultDropdownValues}}
          @additionalFiltersActive={{this.additionalFiltersActive}}
          @filterDropdownsExpanded={{this.rememberedDrawerExpanded}}
          @onFilterDropdownsToggle={{this.persistDrawerState}}
          @inputPlaceholder={{i18n "discourse_ai.logs.search_placeholder"}}
          @initialTextFilter={{this.searchText}}
          @showNoResults={{false}}
          @loading={{this.loading}}
          @onDropdownFilterChange={{this.changeDropdown}}
          @onTextFilterChange={{this.onTextFilterChange}}
          @onResetFilters={{this.clearFilters}}
        >
          <:aboveFilters>
            <div class="ai-logs__periods">
              {{#each this.periodOptions as |period|}}
                <DButton
                  class={{if
                    (eq this.selectedPeriod period.id)
                    "btn-primary"
                    "btn-default"
                  }}
                  @action={{fn this.selectPeriod period.id}}
                  @ariaPressed={{eq this.selectedPeriod period.id}}
                  @translatedLabel={{period.name}}
                />
              {{/each}}
              {{#if (eq this.selectedPeriod "custom")}}
                <div class="ai-logs__date-range">
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
                </div>
              {{/if}}
            </div>
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

            <div class="ai-logs__specialized-filters">
              <DToggleSwitch
                @label="discourse_ai.logs.has_retries"
                @state={{this.hasRetries}}
                {{on "click" this.toggleRetries}}
              />

              <DToggleSwitch
                @label="discourse_ai.logs.unattributed"
                @state={{this.unattributed}}
                {{on "click" this.toggleUnattributed}}
              />
            </div>
          </:additionalFilters>
        </DFilterControls>
      </div>

      <DConditionalLoadingSpinner @condition={{this.loading}}>
        <div class="ai-logs__table-wrap">
          {{#if this.hasNewLogs}}
            <div class="show-more has-topics">
              <a
                tabindex="0"
                href
                class="alert alert-info clickable
                  {{if this.loadingNewLogs 'loading'}}"
                {{on "click" this.showIncomingLogs}}
              >
                <DCountI18n
                  @key="discourse_ai.logs.new_logs_count"
                  @count={{this.newLogsCount}}
                />
                {{#if this.loadingNewLogs}}
                  {{dLoadingSpinner size="small"}}
                {{/if}}
              </a>
            </div>
          {{/if}}

          {{#if this.logs.length}}
            <DLoadMore
              @action={{this.loadMore}}
              @enabled={{this.meta.has_more}}
              @isLoading={{this.loadingMore}}
            >
              <table class="d-table">
                <caption class="sr-only">{{i18n
                    "discourse_ai.logs.table_caption"
                  }}</caption>
                <thead class="d-table__header">
                  <tr class="d-table__row">
                    <th
                      class="d-table__header-cell ai-logs__col-outcome"
                      scope="col"
                    ><span class="sr-only">{{i18n
                          "discourse_ai.logs.outcome"
                        }}</span></th>
                    <th
                      class="d-table__header-cell ai-logs__col-time"
                      scope="col"
                    >{{i18n "discourse_ai.logs.when"}}</th>
                    <th
                      class="d-table__header-cell ai-logs__col-request"
                      scope="col"
                    >{{i18n "discourse_ai.logs.request"}}</th>
                    <th
                      class="d-table__header-cell ai-logs__col-user"
                      scope="col"
                    >{{i18n "discourse_ai.logs.user"}}</th>
                    <th
                      class="d-table__header-cell ai-logs__col-duration"
                      scope="col"
                    >
                      <span class="ai-logs__duration-heading">{{i18n
                          "discourse_ai.logs.duration"
                        }}</span>
                      <span class="ai-logs__tokens-heading">{{i18n
                          "discourse_ai.logs.tokens_direction"
                        }}</span>
                    </th>
                    <th
                      class="d-table__header-cell ai-logs__col-context"
                      scope="col"
                    >{{i18n "discourse_ai.logs.context"}}</th>
                    <th
                      class="d-table__header-cell ai-logs__col-actions"
                      scope="col"
                    ><span class="sr-only">{{i18n
                          "discourse_ai.logs.actions"
                        }}</span></th>
                  </tr>
                </thead>
                <tbody class="d-table__body">
                  {{#each this.logs as |currentLog|}}
                    <AiLogRow
                      @log={{currentLog}}
                      @onOpen={{this.openDetails}}
                    />
                  {{/each}}
                </tbody>
              </table>
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
        </div>
      </DConditionalLoadingSpinner>
    </section>
  </template>
}
