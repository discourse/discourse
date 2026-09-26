import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ToastsService from "discourse/float-kit/services/toasts";

export default class AdminEmbeddingPostsAndTopicsController extends Controller {
  @service(() => ToastsService) toasts;
  @controller adminEmbedding;

  get formData() {
    const embedding = this.adminEmbedding.embedding;

    return {
      embed_by_username: isEmpty(embedding.embed_by_username)
        ? null
        : [embedding.embed_by_username],
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
        type: "posts_and_topics",
        ...data,
        embed_by_username: data.embed_by_username[0],
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin.embedding.posts_and_topics_settings_saved"),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
