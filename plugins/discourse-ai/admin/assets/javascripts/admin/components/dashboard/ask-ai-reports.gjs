import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { formatRange } from "discourse/admin/lib/dashboard-date-range";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import DNativeSelect from "discourse/ui-kit/d-native-select";
import dObserveIntersection from "discourse/ui-kit/modifiers/d-observe-intersection";
import { i18n } from "discourse-i18n";
import AskAiReportSubjects from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai-report-subjects";

const copy = (key) => i18n(`admin.dashboard.ask_ai.reports.${key}`);
const period = (report) => formatRange(report.start_date, report.end_date);
const state = (report) => {
  if (report.report_status === "completed") {
    return null;
  }
  if (report.report_status === "failed") {
    return trustHTML(
      i18n("admin.dashboard.ask_ai.reports.failed", {
        max_asks_url: getURL(
          "/admin/site_settings/category/all_results?filter=ai_ask_ai_report_max_asks"
        ),
      })
    );
  }
  return copy(report.report_status);
};

const reportSettingsURL = getURL(
  "/admin/site_settings/category/all_results?filter=ai_ask_ai_report_"
);

export default class AskAiReports extends Component {
  @tracked reports = [];
  @tracked dataExplorerQueryId;
  @tracked periodQueryId;
  @tracked selectedReportId;
  @tracked loading = true;
  @tracked failed = false;
  @tracked submitting = false;
  @tracked reportOpened = false;
  @tracked reportLoading = false;
  @tracked reportFailed = false;
  @tracked detailedReport;

  @tracked showGenerateModal = false;
  @tracked recipientGroups = [];
  @tracked formApi;
  formData = { sendToGroups: false };
  reportStartDate;
  reportEndDate;

  #timer;
  #detailRequest = 0;

  constructor() {
    super(...arguments);
    this.loadReports();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearTimeout(this.#timer);
  }

  get periodQueryUrl() {
    if (!this.periodQueryId) {
      return;
    }
    const params = encodeURIComponent(
      JSON.stringify({
        start_date: this.args.startDate,
        end_date: this.args.endDate,
      })
    );
    return getURL(
      `/admin/plugins/discourse-data-explorer/queries/${this.periodQueryId}?params=${params}`
    );
  }

  get reportQueryUrl() {
    if (!this.dataExplorerQueryId || !this.visibleReportId) {
      return;
    }
    const params = encodeURIComponent(
      JSON.stringify({ report_id: this.visibleReportId })
    );
    return getURL(
      `/admin/plugins/discourse-data-explorer/queries/${this.dataExplorerQueryId}?params=${params}`
    );
  }

  get visibleReportId() {
    return this.visibleReports[0]?.id;
  }

  get visibleReports() {
    const report =
      this.reports.find(
        (item) => String(item.id) === String(this.selectedReportId)
      ) || this.reports[0];
    return report ? [report] : [];
  }

  get selectedPeriod() {
    return formatRange(this.reportStartDate, this.reportEndDate);
  }

  get pending() {
    return this.reports.some(
      (report) =>
        report.start_date === this.args.startDate &&
        report.end_date === this.args.endDate &&
        ["queued", "running"].includes(report.report_status)
    );
  }

  get disabled() {
    return (
      this.loading ||
      this.args.dashboardLoading ||
      this.submitting ||
      this.pending ||
      !this.args.questions
    );
  }

  get recipientGroupNames() {
    return this.recipientGroups.join(", ");
  }

  @action
  reportEnteredView(entry) {
    if (entry.isIntersecting && !this.reportOpened) {
      this.loadReport();
    }
  }

  @action
  selectReport(id) {
    this.selectedReportId = id;
    this.loadReport();
  }

  @action
  async loadReport() {
    clearTimeout(this.#timer);
    const id = this.visibleReportId;
    if (!id) {
      return;
    }
    const request = ++this.#detailRequest;
    this.reportOpened = true;
    this.reportLoading = true;
    this.reportFailed = false;
    this.detailedReport = null;
    try {
      const result = await ajax(
        `/admin/plugins/discourse-ai/ask-ai-reports/${id}`
      );
      if (this.isDestroying || request !== this.#detailRequest) {
        return;
      }
      this.detailedReport = result.report;
      this.reports = this.reports.map((report) =>
        report.id === result.report.id
          ? { ...report, report_status: result.report.report_status }
          : report
      );
      this.#scheduleRefresh();
    } catch {
      if (!this.isDestroying && request === this.#detailRequest) {
        this.reportFailed = true;
      }
    } finally {
      if (!this.isDestroying && request === this.#detailRequest) {
        this.reportLoading = false;
      }
    }
  }

  @action
  registerFormApi(api) {
    this.formApi = api;
  }

  @action
  openGenerateModal() {
    this.formData = { sendToGroups: false };
    this.reportStartDate = this.args.startDate;
    this.reportEndDate = this.args.endDate;
    this.showGenerateModal = true;
  }

  @action
  closeGenerateModal() {
    this.showGenerateModal = false;
  }

  @action
  async generate(data) {
    this.submitting = true;
    try {
      const result = await ajax("/admin/plugins/discourse-ai/ask-ai-reports", {
        type: "POST",
        data: {
          start_date: this.reportStartDate,
          end_date: this.reportEndDate,
          send_to_groups: data.sendToGroups,
        },
      });
      if (this.isDestroying) {
        return;
      }
      this.reports = [
        result.report,
        ...this.reports.filter((report) => report.id !== result.report.id),
      ];
      this.selectedReportId = String(result.report.id);
      this.#detailRequest++;
      this.detailedReport = null;
      this.reportOpened = true;
      this.reportFailed = false;
      this.reportLoading = false;
      this.#scheduleRefresh();
      if (result.report.report_status === "completed") {
        this.loadReport();
      }
      this.closeGenerateModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      if (!this.isDestroying) {
        this.submitting = false;
      }
    }
  }

  @action
  async loadReports() {
    clearTimeout(this.#timer);
    try {
      const result = await ajax("/admin/plugins/discourse-ai/ask-ai-reports");
      if (this.isDestroying) {
        return;
      }
      this.reports = result.reports;
      this.dataExplorerQueryId = result.data_explorer_query_id;
      this.periodQueryId = result.period_query_id;
      this.recipientGroups = result.recipient_groups ?? [];
      this.failed = false;
    } catch {
      if (!this.isDestroying) {
        this.failed = true;
      }
    } finally {
      if (!this.isDestroying) {
        this.loading = false;
      }
    }
  }

  #scheduleRefresh() {
    clearTimeout(this.#timer);
    if (
      this.reportOpened &&
      ["queued", "running"].includes(this.visibleReports[0]?.report_status)
    ) {
      this.#timer = setTimeout(() => this.loadReport(), 5000);
    }
  }

  <template>
    <div class="db-section__row ask-ai-reports">
      <section class="db-section__row-block">
        <div class="db-section__row-block-header">
          <h3 class="db-section__row-block-title">
            {{#if this.periodQueryUrl}}
              <a href={{this.periodQueryUrl}}>{{copy "title"}}</a>
            {{else}}
              {{copy "title"}}
            {{/if}}
          </h3>
          {{#if this.reports.length}}
            <div class="ask-ai-reports__period-picker">
              <DNativeSelect
                aria-label={{copy "report_period"}}
                @includeNone={{false}}
                @onChange={{this.selectReport}}
                @value={{this.visibleReportId}}
                as |select|
              >
                {{#each this.reports as |report|}}
                  <select.Option @value={{report.id}}>{{period
                      report
                    }}</select.Option>
                {{/each}}
              </DNativeSelect>
            </div>
          {{/if}}
          <DButton
            class="btn-flat ask-ai-reports__generate"
            @action={{this.openGenerateModal}}
            @ariaLabel="admin.dashboard.ask_ai.reports.generate"
            @disabled={{this.disabled}}
            @icon="arrows-rotate"
            @title="admin.dashboard.ask_ai.reports.generate"
          />
        </div>
        {{#each this.visibleReports key="id" as |report|}}
          <article
            class="ask-ai-reports__report"
            {{dObserveIntersection
              this.reportEnteredView
              threshold=0
              isLoading=this.reportOpened
            }}
          >
            {{#if (state report)}}
              <div class="ask-ai-reports__report-header">
                <span class="ask-ai-reports__hint">{{state report}}</span>
              </div>
            {{/if}}
            {{#if this.reportLoading}}
              <p>{{copy "loading"}}</p>
            {{/if}}
            {{#if this.reportFailed}}
              <p role="alert">{{copy "load_failed"}}</p>
              <DButton
                class="ask-ai-reports__retry-report"
                @action={{this.loadReport}}
                @translatedLabel={{copy "reload"}}
              />
            {{/if}}
            {{#if this.detailedReport.subjects.length}}
              <AskAiReportSubjects
                @report={{this.detailedReport}}
                @reportQueryUrl={{this.reportQueryUrl}}
              />
            {{/if}}
          </article>
        {{else}}
          {{#unless this.failed}}
            <p>{{if this.loading (copy "loading") (copy "empty")}}</p>
            {{#unless this.loading}}
              <p class="ask-ai-reports__hint">{{if
                  @questions
                  (copy "empty_help")
                  (copy "no_asks")
                }}</p>
            {{/unless}}
          {{/unless}}
        {{/each}}
        {{#if this.failed}}
          <p role="alert">{{copy "load_failed"}}</p>
          <DButton
            @action={{this.loadReports}}
            @translatedLabel={{copy "reload"}}
          />
        {{/if}}
      </section>
    </div>
    {{#if this.showGenerateModal}}
      <DModal
        @closeModal={{this.closeGenerateModal}}
        @title={{copy "generate"}}
      >
        <:body>
          <p>
            {{i18n
              "admin.dashboard.ask_ai.reports.confirm_period"
              period=this.selectedPeriod
            }}
          </p>
          <Form
            @data={{this.formData}}
            @onRegisterApi={{this.registerFormApi}}
            @onSubmit={{this.generate}}
            as |form|
          >
            {{#if this.recipientGroups.length}}
              <form.Field
                @format="full"
                @name="sendToGroups"
                @title={{i18n
                  "admin.dashboard.ask_ai.reports.send_to_groups"
                  groups=this.recipientGroupNames
                }}
                @type="checkbox"
                as |field|
              >
                <field.Control />
              </form.Field>
            {{/if}}
          </Form>
        </:body>
        <:footer>
          <DButton
            class="btn-primary"
            @action={{this.formApi.submit}}
            @disabled={{this.submitting}}
            @label="admin.dashboard.ask_ai.reports.generate"
          />
          <DModalCancel @close={{this.closeGenerateModal}} />
          <DButton
            class="btn-flat ask-ai-reports__settings"
            rel="noopener noreferrer"
            target="_blank"
            @ariaLabel="admin.dashboard.ask_ai.reports.report_settings"
            @href={{reportSettingsURL}}
            @icon="gear"
            @title="admin.dashboard.ask_ai.reports.report_settings"
          />
        </:footer>
      </DModal>
    {{/if}}
  </template>
}
