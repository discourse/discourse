import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminPluginsExplorerNew extends Controller {
  @service store;
  @service router;
  @service toasts;
  @service siteSettings;

  @tracked loading = false;
  aiFormData = { ai_description: "" };

  get aiQueriesEnabled() {
    return this.siteSettings.data_explorer_ai_queries_enabled;
  }

  @action
  async create({ name, description }) {
    await this._createQuery({
      name: name.trim(),
      description: description?.trim(),
    });
  }

  @action
  async createWithAi({ ai_description }) {
    await this._createQuery({
      name: i18n("explorer.ai.generating_name"),
      ai_description: ai_description.trim(),
    });
  }

  async _createQuery(data) {
    try {
      this.loading = true;
      const result = await this.store.createRecord("query", data).save();
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
}
