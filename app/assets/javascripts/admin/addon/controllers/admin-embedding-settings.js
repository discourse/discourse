import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminEmbeddingSettingsController extends Controller {
  @service toasts;
  @controller adminEmbedding;

  get formData() {
    const embedding = this.adminEmbedding.embedding;
    return {
      embed_by_username: isEmpty(embedding.embed_by_username)
        ? null
        : embedding.embed_by_username,
      embed_post_limit: embedding.embed_post_limit,
      embed_title_scrubber: embedding.embed_title_scrubber,
      embed_truncate: embedding.embed_truncate,
      embed_unlisted: embedding.embed_unlisted,
    };
  }

  @action
  async save(data) {
    const embedding = this.adminEmbedding.embedding;

    try {
      await embedding.update({
        ...data,
        embed_by_username: data.embed_by_username[0],
      });
      this.toasts.success({
        duration: 1500,
        data: { message: i18n("admin.embedding.embedding_settings_saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
