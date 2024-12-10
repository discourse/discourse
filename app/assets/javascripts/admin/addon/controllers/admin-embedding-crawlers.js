import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminEmbeddingCrawlersController extends Controller {
  @service toasts;
  @controller adminEmbedding;

  get formData() {
    const embedding = this.adminEmbedding.embedding;

    return {
      allowed_embed_selectors: embedding.allowed_embed_selectors,
      blocked_embed_selectors: embedding.blocked_embed_selectors,
      allowed_embed_classnames: embedding.allowed_embed_classnames,
    };
  }

  @action
  async save(data) {
    const embedding = this.adminEmbedding.embedding;

    try {
      await embedding.update({
        type: "crawlers",
        ...data,
      });
      this.toasts.success({
        duration: 1500,
        data: { message: i18n("admin.embedding.crawler_settings_saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
