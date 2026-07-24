import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n, { i18n } from "discourse-i18n";
import { subscribeToAiGeneration } from "discourse/plugins/discourse-data-explorer/discourse/lib/ai-generation";
import { dataExplorerAiQueriesEnabled } from "discourse/plugins/discourse-data-explorer/discourse/lib/ai-query-availability";
import { defaultView } from "discourse/plugins/discourse-data-explorer/discourse/lib/chart-helpers";
import {
  dataExplorerStore,
  rememberedMode,
  rememberMode,
} from "discourse/plugins/discourse-data-explorer/discourse/lib/data-explorer-store";

const HIDE_SCHEMA_KEY = "hide_schema";

export default class AdminPluginsExplorerNew extends Controller {
  @service store;
  @service router;
  @service toasts;
  @service siteSettings;
  @service messageBus;

  @tracked loading = false;
  @tracked aiGenerating = false;
  @tracked hasGenerated = false;
  @tracked aiDescription = "";
  @tracked generatedSql = "";
  @tracked generatedName = "";
  @tracked generatedDescription = "";
  @tracked mode = rememberedMode() ?? "ai";
  @tracked schema = null;
  @tracked hideSchema = dataExplorerStore.get(HIDE_SCHEMA_KEY) === "true";
  @tracked manualSql = "SELECT 1";
  @tracked previewLoading = false;
  @tracked previewResults = null;
  @tracked showPreview = false;
  @tracked view = "sql";

  manualFormData = { name: "", description: "" };
  _teardownAiGeneration = null;

  get previewDisabled() {
    return (
      this.aiGenerating || this.previewLoading || !this.generatedSql.trim()
    );
  }

  get viewItems() {
    return [
      { value: "chart", icon: "signal" },
      { value: "table", icon: "table" },
      { value: "sql", icon: "code" },
    ];
  }

  get previewSucceeded() {
    return this.showPreview && this.previewResults?.success;
  }

  get previewResultCount() {
    if (!this.previewSucceeded) {
      return null;
    }
    const count = this.previewResults.result_count;
    if (count === this.previewResults.default_limit) {
      return i18n("explorer.max_result_count", { count });
    }
    return i18n("explorer.result_count", { count });
  }

  get previewDuration() {
    if (!this.previewSucceeded) {
      return null;
    }
    return i18n("explorer.run_time", {
      value: I18n.toNumber(this.previewResults.duration, { precision: 1 }),
    });
  }

  @action
  setView(value) {
    this.view = value;
  }

  get aiQueriesEnabled() {
    return dataExplorerAiQueriesEnabled(this.siteSettings);
  }

  @action
  handleKeydown(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault();
      this.generate();
    }
  }

  @action
  setMode(value) {
    this.mode = value;
    rememberMode(value);
  }

  @action
  updateManualSql(value) {
    this.manualSql = value;
  }

  @action
  updateHideSchema(value) {
    this.hideSchema = value;
    dataExplorerStore.set({ key: HIDE_SCHEMA_KEY, value: value.toString() });
  }

  @action
  async create({ name, description }) {
    try {
      this.loading = true;
      const result = await this.store
        .createRecord("query", {
          name: name.trim(),
          description: description?.trim(),
          sql: this.manualSql,
        })
        .save();
      this.toasts.success({
        data: { message: i18n("explorer.query_created") },
      });
      this.router.transitionTo(
        "adminPlugins.show.explorer.edit",
        result.target.id
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async generate() {
    if (this.aiGenerating || !this.aiDescription.trim()) {
      return;
    }

    this._teardownAi();
    this.aiGenerating = true;
    this.showPreview = false;
    this.previewResults = null;

    try {
      const response = await ajax(
        "/admin/plugins/discourse-data-explorer/queries/generate.json",
        {
          type: "POST",
          data: {
            ai_description: this.aiDescription.trim(),
            existing_sql: this.generatedSql || undefined,
          },
        }
      );

      this._teardownAiGeneration = subscribeToAiGeneration({
        messageBus: this.messageBus,
        generationId: response.generation_id,
        onComplete: (data) => {
          this.generatedSql = data.sql;
          this.generatedName = data.name;
          this.generatedDescription = data.description;
          this.hasGenerated = true;
          this.aiGenerating = false;
          // prioritise the result: run straight away so the data is what the
          // user sees, with the SQL one tab away
          this.runPreview();
        },
        onError: (data) => {
          this.aiGenerating = false;
          this.toasts.error({
            data: {
              message: data.error || i18n("explorer.ai.generation_error"),
            },
          });
        },
        onTimeout: () => {
          this.aiGenerating = false;
          this.toasts.error({
            data: { message: i18n("explorer.ai.generation_timeout") },
          });
        },
      });
    } catch (error) {
      this.aiGenerating = false;
      popupAjaxError(error);
    }
  }

  @action
  async runPreview() {
    if (this.previewDisabled) {
      return;
    }

    this.previewLoading = true;
    this.showPreview = false;

    try {
      const result = await ajax(
        "/admin/plugins/discourse-data-explorer/queries/preview.json",
        {
          type: "POST",
          data: {
            sql: this.generatedSql,
            name: this.generatedName || undefined,
          },
        }
      );
      this.previewResults = result;
      this.showPreview = true;
      if (result.success && this.view === "sql") {
        this.view = defaultView(result);
      }
    } catch (error) {
      if (error.jqXHR?.status === 422 && error.jqXHR.responseJSON) {
        this.previewResults = error.jqXHR.responseJSON;
        this.showPreview = true;
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.previewLoading = false;
    }
  }

  @action
  async saveQuery() {
    try {
      this.loading = true;
      const result = await this.store
        .createRecord("query", {
          name: this.generatedName,
          description: this.generatedDescription,
          sql: this.generatedSql,
        })
        .save();
      this.toasts.success({
        data: { message: i18n("explorer.query_created") },
      });
      // Run the query straight away — there's nothing new to do on the edit
      // page first, so save and show the results in one step.
      this.router.transitionTo(
        "adminPlugins.show.explorer.edit",
        result.target.id,
        { queryParams: { run: true } }
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  updateAiDescription(event) {
    this.aiDescription = event.target.value;
  }

  @action
  updateSql(newSql) {
    this.generatedSql = newSql;
  }

  @action
  updateName(value) {
    this.generatedName = value;
  }

  @action
  updateDescription(event) {
    this.generatedDescription = event.target.value;
  }

  _teardownAi() {
    this._teardownAiGeneration?.();
    this._teardownAiGeneration = null;
  }

  resetState() {
    this._teardownAi();
    this.aiGenerating = false;
    this.hasGenerated = false;
    this.aiDescription = "";
    this.generatedSql = "";
    this.generatedName = "";
    this.generatedDescription = "";
    this.mode = rememberedMode() ?? "ai";
    this.schema = null;
    this.hideSchema = dataExplorerStore.get(HIDE_SCHEMA_KEY) === "true";
    this.manualSql = "SELECT 1";
    this.loading = false;
    this.manualFormData = { name: "", description: "" };
    this.previewLoading = false;
    this.previewResults = null;
    this.showPreview = false;
    this.view = "sql";
  }
}
