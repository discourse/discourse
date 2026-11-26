import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Composer, { ADD_TRANSLATION, EDIT } from "discourse/models/composer";
import ImageDescriptionsModal from "../components/modal/image-descriptions.gjs";
import { imageBase62Sha1 } from "../lib/post-image-caption-editor.js";

export default class PostImageCaptionEditor extends Service {
  @service composer;
  @service modal;
  @service site;
  @service siteSettings;

  get enabled() {
    const model = this.composer.model;
    return Boolean(
      this.siteSettings.discourse_ai_enabled &&
      this.siteSettings.ai_post_image_captions_enabled &&
      model &&
      !model.privateMessage &&
      !model.post?.topic?.isPrivateMessage
    );
  }

  open({ alt, image, onSaveAlt }) {
    if (!this.enabled) {
      return;
    }

    this.modal.show(ImageDescriptionsModal, {
      model: {
        alt: alt || "",
        base62Sha1: imageBase62Sha1(image),
        context: this.captureContext(),
        onSaveAlt,
      },
    });
  }

  captureContext() {
    const model = this.composer.model;
    const { action, post, topic } = model;
    const locale =
      (action === ADD_TRANSLATION
        ? this.composer.selectedTranslationLocale
        : model.locale) || "";

    const isEditingPost = action === EDIT || action === ADD_TRANSLATION;
    const canEditCaption = Boolean(
      isEditingPost &&
      post?.id &&
      (action !== ADD_TRANSLATION || locale) &&
      !post.deleted_at &&
      !topic?.deleted_at &&
      !post.topic?.deleted_at &&
      post.post_type === this.site.post_types.regular
    );

    return {
      model,
      action,
      postId: post?.id,
      locale,
      isEditingPost,
      canEditCaption,
    };
  }

  isCurrent(context) {
    if (!this.enabled || this.composer.model.composeState === Composer.CLOSED) {
      return false;
    }

    const current = this.captureContext();
    return ["model", "action", "postId", "locale", "canEditCaption"].every(
      (key) => current[key] === context[key]
    );
  }

  load({ postId, locale }) {
    return ajax(`/discourse-ai/post-image-captions/${postId}`, {
      data: locale ? { locale } : {},
    });
  }

  save({ postId, locale }, base62Sha1, description) {
    return ajax(`/discourse-ai/post-image-captions/${postId}/${base62Sha1}`, {
      type: "PUT",
      data: { description, ...(locale ? { locale } : {}) },
    });
  }
}
