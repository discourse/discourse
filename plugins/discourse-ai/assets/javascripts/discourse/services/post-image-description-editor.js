import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { EDIT } from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export default class PostImageDescriptionEditor extends Service {
  @service a11y;
  @service composer;
  @service siteSettings;
  @service toasts;

  @tracked descriptions = new Map();
  @tracked loadedKey = null;
  @tracked loadingKey = null;

  get canEditCurrentComposer() {
    return Boolean(
      this.siteSettings.ai_post_image_descriptions_enabled &&
      this.composer.model?.action === EDIT &&
      this.currentPostId
    );
  }

  get currentPostId() {
    return this.composer.model?.post?.id;
  }

  get currentLocale() {
    return this.composer.model?.locale;
  }

  get currentKey() {
    if (!this.currentPostId) {
      return;
    }

    return `${this.currentPostId}:${this.currentLocale || ""}`;
  }

  descriptionFor(base62Sha1) {
    if (!this.canEditCurrentComposer || this.loadedKey !== this.currentKey) {
      return;
    }

    return this.descriptions.get(base62Sha1);
  }

  async ensureLoaded() {
    if (!this.canEditCurrentComposer) {
      this.#reset();
      return;
    }

    const key = this.currentKey;
    if (this.loadedKey === key || this.loadingKey === key) {
      return;
    }

    this.loadingKey = key;
    this.loadedKey = null;
    this.descriptions = new Map();

    try {
      const result = await ajax(
        `/discourse-ai/post-image-descriptions/${this.currentPostId}`,
        {
          data: this.currentLocale ? { locale: this.currentLocale } : {},
        }
      );

      if (this.currentKey === key) {
        this.descriptions = new Map(
          result.descriptions.map((description) => [
            description.base62_sha1,
            description.description,
          ])
        );
        this.loadedKey = key;
      }
    } catch {
      if (this.currentKey === key) {
        this.descriptions = new Map();
        this.loadedKey = key;
      }
    } finally {
      if (this.loadingKey === key) {
        this.loadingKey = null;
      }
    }
  }

  async save(base62Sha1, description) {
    try {
      const result = await ajax(
        `/discourse-ai/post-image-descriptions/${this.currentPostId}/${base62Sha1}`,
        {
          type: "PUT",
          data: {
            description,
            ...(this.currentLocale ? { locale: this.currentLocale } : {}),
          },
        }
      );

      const descriptions = new Map(this.descriptions);
      descriptions.set(result.base62_sha1, result.description);
      this.descriptions = descriptions;
      this.loadedKey = this.currentKey;

      const message = i18n("discourse_ai.post_image_descriptions.saved");
      this.toasts.success({
        duration: "short",
        data: { message },
      });
      this.a11y.announce(message, "polite");

      return result;
    } catch (error) {
      popupAjaxError(error);
      throw error;
    }
  }

  #reset() {
    this.descriptions = new Map();
    this.loadedKey = null;
    this.loadingKey = null;
  }
}
