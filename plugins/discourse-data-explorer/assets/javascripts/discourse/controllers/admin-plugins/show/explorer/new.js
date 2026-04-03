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

  @tracked loading = false;

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
        "adminPlugins.show.explorer.details",
        result.target.id
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }
}
