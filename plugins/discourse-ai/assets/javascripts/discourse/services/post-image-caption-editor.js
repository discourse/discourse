import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { ADD_TRANSLATION, EDIT } from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export default class PostImageCaptionEditor extends Service {
  @service a11y;
  @service composer;
  @service siteSettings;
  @service toasts;

  @tracked captions = new Map();
  @tracked loadedKey = null;
  @tracked loadingKey = null;

  get canEditCurrentComposer() {
    const action = this.composer.model?.action;

    return Boolean(
      this.siteSettings.ai_post_image_captions_enabled &&
      this.currentPostId &&
      (action === EDIT || (action === ADD_TRANSLATION && this.currentLocale))
    );
  }

  get currentPostId() {
    return this.composer.model?.post?.id;
  }

  get currentLocale() {
    if (this.composer.model?.action === ADD_TRANSLATION) {
      return this.composer.selectedTranslationLocale;
    }

    return this.composer.model?.locale;
  }

  get currentKey() {
    if (!this.currentPostId) {
      return;
    }

    return `${this.currentPostId}:${this.currentLocale || ""}`;
  }

  captionFor(base62Sha1) {
    if (!this.canEditCurrentComposer || this.loadedKey !== this.currentKey) {
      return;
    }

    return this.captions.get(base62Sha1);
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
    this.captions = new Map();

    try {
      const result = await ajax(
        `/discourse-ai/post-image-captions/${this.currentPostId}`,
        {
          data: this.currentLocale ? { locale: this.currentLocale } : {},
        }
      );

      if (this.currentKey === key) {
        this.captions = new Map(
          result.captions.map((caption) => [
            caption.base62_sha1,
            caption.description,
          ])
        );
        this.loadedKey = key;
      }
    } catch {
      if (this.currentKey === key) {
        this.captions = new Map();
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
        `/discourse-ai/post-image-captions/${this.currentPostId}/${base62Sha1}`,
        {
          type: "PUT",
          data: {
            description,
            ...(this.currentLocale ? { locale: this.currentLocale } : {}),
          },
        }
      );

      const captions = new Map(this.captions);
      captions.set(result.base62_sha1, result.description);
      this.captions = captions;
      this.loadedKey = this.currentKey;

      const message = i18n("discourse_ai.post_image_captions.saved");
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
    this.captions = new Map();
    this.loadedKey = null;
    this.loadingKey = null;
  }
}
