import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
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
  @tracked generatedSql = "";
  @tracked mode = rememberedMode() ?? "ai";
  @tracked schema = null;
  @tracked groups = null;
  @tracked availableTags = [];
  @tracked hideSchema = dataExplorerStore.get(HIDE_SCHEMA_KEY) === "true";
  @tracked manualSql = "SELECT 1";
  @tracked previewLoading = false;
  @tracked previewResults = null;
  @tracked showPreview = false;
  @tracked view = "sql";
  @tracked aiPromptData = { prompt: "" };
  @tracked aiFormData = null;

  manualFormData = { name: "", description: "", groupIds: [], tags: [] };
  #aiPromptApi = null;
  #aiFormApi = null;
  _teardownAiGeneration = null;

  get previewDisabled() {
    return (
      this.aiGenerating || this.previewLoading || !this.generatedSql.trim()
    );
  }

  get groupOptions() {
    return (this.groups ?? []).filter(
      (group) =>
        group.id !== AUTO_GROUPS.everyone.id &&
        group.id !== AUTO_GROUPS.anonymous_users.id &&
        group.id !== AUTO_GROUPS.logged_in_users.id
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

  get aiQueriesEnabled() {
    return dataExplorerAiQueriesEnabled(this.siteSettings);
  }

  get isAiMode() {
    return this.aiQueriesEnabled && this.mode === "ai";
  }

  @action
  setView(value) {
    this.view = value;
  }

  @action
  setMode(value) {
    // the AI forms unmount in manual mode, so keep their edits for when they return
    if (this.mode === "ai" && this.#aiPromptApi) {
      this.aiPromptData = { prompt: this.#aiPromptApi.get("prompt") };
      this.#aiPromptApi = null;
    }

    if (this.mode === "ai" && this.#aiFormApi) {
      this.aiFormData = {
        name: this.#aiFormApi.get("name"),
        description: this.#aiFormApi.get("description"),
        groupIds: this.#aiFormApi.get("groupIds"),
        tags: this.#aiFormApi.get("tags"),
      };
      this.#aiFormApi = null;
    }

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
  registerAiPromptApi(api) {
    this.#aiPromptApi = api;
  }

  @action
  submitAiPrompt() {
    this.#aiPromptApi?.submit();
  }

  @action
  registerAiFormApi(api) {
    this.#aiFormApi = api;
  }

  @action
  async create({ name, description, groupIds, tags }) {
    try {
      this.loading = true;
      const result = await this.store
        .createRecord("query", {
          name: name.trim(),
          description: description?.trim(),
          sql: this.manualSql,
          group_ids: groupIds,
          tags,
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
  async generate({ prompt }) {
    if (this.aiGenerating) {
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
            ai_description: prompt.trim(),
            existing_sql: this.generatedSql || undefined,
          },
        }
      );

      this._teardownAiGeneration = subscribeToAiGeneration({
        messageBus: this.messageBus,
        generationId: response.generation_id,
        onComplete: (data) => {
          this.generatedSql = data.sql;
          this.#applyGeneratedDetails(data);
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
            name: this.#aiFormApi?.get("name") || undefined,
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
  async saveQuery({ name, description, groupIds, tags }) {
    try {
      this.loading = true;
      const result = await this.store
        .createRecord("query", {
          name: name.trim(),
          description: description?.trim(),
          sql: this.generatedSql,
          group_ids: groupIds,
          tags,
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
  updateSql(newSql) {
    this.generatedSql = newSql;
  }

  resetState() {
    this._teardownAi();
    this.aiGenerating = false;
    this.hasGenerated = false;
    this.aiPromptData = { prompt: "" };
    this.#aiPromptApi = null;
    this.generatedSql = "";
    this.aiFormData = null;
    this.#aiFormApi = null;
    this.mode = rememberedMode() ?? "ai";
    this.schema = null;
    this.groups = null;
    this.availableTags = [];
    this.hideSchema = dataExplorerStore.get(HIDE_SCHEMA_KEY) === "true";
    this.manualSql = "SELECT 1";
    this.loading = false;
    this.manualFormData = {
      name: "",
      description: "",
      groupIds: [],
      tags: [],
    };
    this.previewLoading = false;
    this.previewResults = null;
    this.showPreview = false;
    this.view = "sql";
  }

  // A regenerate updates the mounted form in place, committing so the new
  // values don't count as unsaved edits.
  async #applyGeneratedDetails({ name, description }) {
    const formApi = this.#aiFormApi;
    if (formApi) {
      await formApi.setProperties({ name, description });
      formApi.commit();
    } else {
      this.aiFormData = {
        groupIds: [],
        tags: [],
        ...this.aiFormData,
        name,
        description,
      };
    }
  }

  _teardownAi() {
    this._teardownAiGeneration?.();
    this._teardownAiGeneration = null;
  }
}
