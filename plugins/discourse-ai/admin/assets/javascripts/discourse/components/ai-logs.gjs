import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import Form from "discourse/components/form";
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
import { i18n } from "discourse-i18n";
import AiLogRow from "discourse/plugins/discourse-ai/discourse/components/ai-log-row";
import AiLogDetailModal from "./modal/ai-log-detail-modal";
import AiLogRetentionModal from "./modal/ai-log-retention-modal";

const ALL_FILTER_VALUE = "__all__";
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

  filterFormApi;
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
    this.filterFormData = this.buildFilterFormData();

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

  // must stay referentially stable: a new object passed as Form @data
  // recreates the form and drops input focus
  buildFilterFormData() {
    return {
      period: this.selectedPeriod,
      date_range: { from: this.startDate, to: this.endDate },
      usernames: this.selectedUsernames,
      has_retries: this.hasRetries,
      unattributed: this.unattributed,
      id_type: this.idType,
      id_value: this.idValue,
    };
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
      { value: ALL_FILTER_VALUE, label: i18n("discourse_ai.logs.all_models") },
      ...options,
    ];
  }

  @cached
  get featureOptions() {
    const features = [...this.features];
    if (this.selectedFeature && !features.includes(this.selectedFeature)) {
      features.push(this.selectedFeature);
    }

    return [
      {
        value: ALL_FILTER_VALUE,
        label: i18n("discourse_ai.logs.all_features"),
      },
      ...features.map((feature) => ({ value: feature, label: feature })),
    ];
  }

  @cached
  get dropdownOptions() {
    return {
      outcome: this.outcomeOptions,
      model: this.modelOptions,
      feature: this.featureOptions,
    };
  }

  @cached
  get dropdownValues() {
    return {
      outcome: this.selectedOutcome || ALL_FILTER_VALUE,
      model: this.selectedModel || ALL_FILTER_VALUE,
      feature: this.selectedFeature || ALL_FILTER_VALUE,
    };
  }

  @cached
  get defaultDropdownValues() {
    return {
      outcome: ALL_FILTER_VALUE,
      model: ALL_FILTER_VALUE,
      feature: ALL_FILTER_VALUE,
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
      return params;
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
  async refresh({ focusFilters = false } = {}) {
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
      if (focusFilters) {
        next(() =>
          document
            .querySelector(
              ".ai-logs .d-filter-controls__toggle-filters, .ai-logs .d-filter-controls__dropdown"
            )
            ?.focus()
        );
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
  registerFilterFormApi(api) {
    this.filterFormApi = api;
  }

  @action
  applyFilterForm(data) {
    this.selectedPeriod = data.period || undefined;
    this.startDate = data.date_range?.from || this.startDate;
    this.endDate = data.date_range?.to || this.endDate;
    this.hasRetries = Boolean(data.has_retries);
    this.unattributed = Boolean(data.unattributed);
    this.selectedUsernames = this.unattributed ? [] : data.usernames || [];
    this.idType = data.id_type || "id";
    this.idValue = data.id_value || undefined;
    this.refresh();
  }

  @action
  selectPeriod(period) {
    this.selectedPeriod = this.selectedPeriod === period ? undefined : period;
    this.filterFormApi?.set("period", this.selectedPeriod);
    if (this.selectedPeriod && this.selectedPeriod !== "custom") {
      this.endDate = new Date();
      this.startDate = moment()
        .subtract(PERIODS[this.selectedPeriod], "hours")
        .toDate();
      this.filterFormApi?.set("date_range", {
        from: this.startDate,
        to: this.endDate,
      });
    }
    this.refresh();
  }

  @action
  changeDateRange(value) {
    this.filterFormApi?.set("date_range", value);
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
    } else if (key === "feature") {
      this.selectedFeature = selectedValue;
    }

    this.refresh();
  }

  @action
  changeUser(usernames) {
    const selectedUsernames = usernames || [];
    this.filterFormApi?.set("usernames", selectedUsernames);
    this.filterFormApi?.set("unattributed", false);
    this.selectedUsernames = selectedUsernames;
    this.unattributed = false;
    this.refresh();
  }

  @action
  toggleRetries(value, { set }) {
    set("has_retries", value);
    this.hasRetries = Boolean(value);
    this.refresh();
  }

  @action
  toggleUnattributed(value, { set }) {
    set("unattributed", value);
    this.unattributed = Boolean(value);
    if (this.unattributed) {
      set("usernames", []);
      this.selectedUsernames = [];
    }
    this.refresh();
  }

  @action
  setIdValue(value, { set }) {
    set("id_value", value);
    this.idValue = value || undefined;
  }

  @action
  changeIdType(value, { set }) {
    set("id_type", value);
    this.idType = value;
    if (this.idValue) {
      this.refresh();
    }
  }

  @action
  clearFilters() {
    const cleared = {
      period: undefined,
      date_range: {
        from: moment().subtract(24, "hours").toDate(),
        to: new Date(),
      },
      usernames: [],
      has_retries: false,
      unattributed: false,
      id_type: "id",
      id_value: undefined,
    };
    this.filterFormApi?.setProperties(cleared);
    this.selectedPeriod = undefined;
    this.startDate = cleared.date_range.from;
    this.endDate = cleared.date_range.to;
    this.selectedOutcome = undefined;
    this.hasRetries = false;
    this.selectedModel = undefined;
    this.selectedFeature = undefined;
    this.selectedUsernames = [];
    this.unattributed = false;
    this.idType = "id";
    this.idValue = undefined;
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

      <Form
        class="ai-logs__filters"
        @data={{this.filterFormData}}
        @onRegisterApi={{this.registerFilterFormApi}}
        @onSubmit={{this.applyFilterForm}}
        as |form|
      >
        <form.Fieldset
          class="ai-logs__period-field"
          @name="period-filter"
          @title={{i18n "discourse_ai.logs.filters.period"}}
        >
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
          </div>
        </form.Fieldset>

        {{#if (eq this.selectedPeriod "custom")}}
          <form.Fieldset
            class="ai-logs__date-range-field"
            @name="date-range-filter"
            @title={{i18n "discourse_ai.logs.filters.date_range"}}
          >
            <div class="ai-logs__date-range">
              <DDateTimeInputRange
                @from={{this.startDate}}
                @to={{this.endDate}}
                @showFromTime={{false}}
                @showToTime={{false}}
                @onChange={{this.changeDateRange}}
              />
              <form.Submit
                class="btn-default"
                @label="discourse_ai.logs.apply"
              />
            </div>
          </form.Fieldset>
        {{/if}}

        <form.Fieldset
          class="ai-logs__filter-panel"
          @name="log-filters"
          @title={{i18n "discourse_ai.logs.filters.title"}}
        >
          <DFilterControls
            @array={{this.logs}}
            @dropdownOptions={{this.dropdownOptions}}
            @dropdownValue={{this.dropdownValues}}
            @defaultDropdownValue={{this.defaultDropdownValues}}
            @filterDropdownsExpanded={{true}}
            @showDropdownFilterToggle={{false}}
            @showTextFilter={{false}}
            @showResetButton={{false}}
            @showNoResults={{false}}
            @loading={{this.loading}}
            @onDropdownFilterChange={{this.changeDropdown}}
          />

          <div class="ai-logs__specialized-filters">
            <form.Fieldset
              class="ai-logs__user-filter"
              @name="user-filter"
              @title={{i18n "discourse_ai.logs.user"}}
            >
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
            </form.Fieldset>

            <form.Field
              class="ai-logs__toggle"
              @name="has_retries"
              @title={{i18n "discourse_ai.logs.has_retries"}}
              @type="checkbox"
              @onSet={{this.toggleRetries}}
              as |field|
            >
              <field.Control />
            </form.Field>

            <form.Field
              class="ai-logs__toggle"
              @name="unattributed"
              @title={{i18n "discourse_ai.logs.unattributed"}}
              @type="checkbox"
              @onSet={{this.toggleUnattributed}}
              as |field|
            >
              <field.Control />
            </form.Field>
          </div>

          <div class="ai-logs__id-filter">
            <form.Field
              @name="id_type"
              @title={{i18n "discourse_ai.logs.filters.id_type"}}
              @type="select"
              @onSet={{this.changeIdType}}
              as |field|
            >
              <field.Control @includeNone={{false}} as |select|>
                {{#each this.idTypeOptions as |idType|}}
                  <select.Option @value={{idType.id}}>
                    {{idType.name}}
                  </select.Option>
                {{/each}}
              </field.Control>
            </form.Field>

            <form.Field
              @name="id_value"
              @title={{i18n "discourse_ai.logs.filters.id_value"}}
              @type="input-number"
              @onSet={{this.setIdValue}}
              as |field|
            >
              <field.Control
                min="1"
                max={{MAX_SAFE_ID}}
                placeholder={{i18n "discourse_ai.logs.id_placeholder"}}
              />
            </form.Field>

            <form.Submit
              class="btn-default ai-logs__find"
              @label="discourse_ai.logs.find"
            />
            {{#if this.hasFilters}}
              <DButton
                class="btn-transparent ai-logs__clear"
                @action={{this.clearFilters}}
                @label="discourse_ai.logs.clear_filters"
              />
            {{/if}}
          </div>
        </form.Fieldset>

      </Form>

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
            {{#if this.hasFilters}}
              <DButton
                class="btn-default"
                @action={{this.clearFilters}}
                @label="discourse_ai.logs.clear_filters"
              />
            {{/if}}
          </div>
        {{/if}}
      </DConditionalLoadingSpinner>
    </section>
  </template>
}
