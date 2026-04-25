import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

const AI_GENERATION_CHANNEL_PREFIX =
  "/discourse-data-explorer/queries/ai-generation";
const AI_GENERATION_TIMEOUT_MS = 60000;

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
  @tracked showManualForm = false;

  currentGenerationId = null;
  _aiGenerationTimer = null;

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
  toggleManualForm() {
    this.showManualForm = true;
  }

  @action
  toggleAiForm() {
    this.showManualForm = false;
  }

  @action
  async create({ name, description }) {
    try {
      this.loading = true;
      const result = await this.store
        .createRecord("query", {
          name: name.trim(),
          description: description?.trim(),
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

    this._teardownMessageBus();
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

      this.currentGenerationId = response.generation_id;
      this._subscribeToGeneration(this.currentGenerationId);
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

  _subscribeToGeneration(generationId) {
    const channel = `${AI_GENERATION_CHANNEL_PREFIX}/${generationId}`;
    this.messageBus.subscribe(channel, this._onAiGenerationMessage, -1);

    this._aiGenerationTimer = setTimeout(() => {
      this._teardownMessageBus();
      this.aiGenerating = false;
      this.toasts.error({
        data: { message: i18n("explorer.ai.generation_timeout") },
      });
    }, AI_GENERATION_TIMEOUT_MS);
  }

  @bind
  _onAiGenerationMessage(data) {
    if (data.generation_id !== this.currentGenerationId) {
      return;
    }

    if (data.status === "complete") {
      this.generatedSql = data.sql;
      this.generatedName = data.name;
      this.generatedDescription = data.description;
      this.hasGenerated = true;
      this.aiGenerating = false;
      this._teardownMessageBus();
    } else if (data.status === "error") {
      this.aiGenerating = false;
      this._teardownMessageBus();
      this.toasts.error({
        data: {
          message: data.error || i18n("explorer.ai.generation_error"),
        },
      });
    }
  }

  _teardownMessageBus() {
    if (this.currentGenerationId) {
      const channel = `${AI_GENERATION_CHANNEL_PREFIX}/${this.currentGenerationId}`;
      this.messageBus.unsubscribe(channel, this._onAiGenerationMessage);
    }
    if (this._aiGenerationTimer) {
      clearTimeout(this._aiGenerationTimer);
      this._aiGenerationTimer = null;
    }
  }

  resetState() {
    this._teardownMessageBus();
    this.currentGenerationId = null;
    this.aiGenerating = false;
    this.hasGenerated = false;
    this.aiDescription = "";
    this.generatedSql = "";
    this.generatedName = "";
    this.generatedDescription = "";
    this.showManualForm = false;
    this.loading = false;
  }
}
