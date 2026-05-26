import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { subscribeToAiGeneration } from "discourse/plugins/discourse-data-explorer/discourse/lib/ai-generation";

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
  @tracked mode = "ai";
  @tracked schema = null;
  @tracked manualSql = "SELECT 1";

  manualFormData = { name: "", description: "" };
  _teardownAiGeneration = null;

  get aiQueriesEnabled() {
    return this.siteSettings.data_explorer_ai_queries_enabled;
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
  }

  @action
  updateManualSql(value) {
    this.manualSql = value;
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
    this.mode = "ai";
    this.schema = null;
    this.manualSql = "SELECT 1";
    this.loading = false;
    this.manualFormData = { name: "", description: "" };
  }
}
