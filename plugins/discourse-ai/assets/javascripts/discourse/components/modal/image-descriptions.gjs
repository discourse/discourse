import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { uniqueId } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

const PREFIX = "discourse_ai.post_image_captions.image_descriptions";
const t = (key) => i18n(`${PREFIX}.${key}`);
const normalizeAlt = (alt) => (alt ?? "").replace(/\s*\r?\n\s*/g, " ").trim();

export default class ImageDescriptionsModal extends Component {
  @service a11y;
  @service postImageCaptionEditor;
  @service toasts;

  @tracked altSaveFailed = false;
  @tracked description;
  @tracked isApplying = false;
  @tracked isLoading = Boolean(
    this.args.model.base62Sha1 && this.args.model.context.canEditCaption
  );
  @tracked loadFailed = false;

  formData = { alt: normalizeAlt(this.args.model.alt) };

  get unavailableMessage() {
    const { base62Sha1, context } = this.args.model;
    if (this.isLoading) {
      return t("loading");
    } else if (this.loadFailed) {
      return t("load_failed");
    } else if (
      !base62Sha1 ||
      (context.isEditingPost && !context.canEditCaption)
    ) {
      return t("not_supported");
    }
    return t("pending");
  }

  get #isCurrent() {
    return (
      !this.isDestroying &&
      this.postImageCaptionEditor.isCurrent(this.args.model.context)
    );
  }

  @action
  async registerForm(form) {
    if (!this.isLoading) {
      return;
    }

    const { base62Sha1, context } = this.args.model;
    try {
      const result = await this.postImageCaptionEditor.load(context);
      const description = result.captions
        .find((caption) => caption.base62_sha1 === base62Sha1)
        ?.description?.trim();

      if (this.#isCurrent && description) {
        await form.set("description", description);
        if (this.#isCurrent) {
          form.commitField("description");
          this.description = description;
        }
      }
    } catch {
      if (this.#isCurrent) {
        this.loadFailed = true;
      }
    } finally {
      if (!this.isDestroying) {
        this.isLoading = false;
      }
    }
  }

  @action
  async apply(data) {
    if (this.isLoading) {
      return;
    }

    if (!this.#isCurrent) {
      this.args.closeModal();
      return;
    }

    this.isApplying = true;
    try {
      await this.#applyDescriptions(data);
    } finally {
      this.isApplying = false;
    }
  }

  async #applyDescriptions(data) {
    this.altSaveFailed = false;
    const { alt, base62Sha1, context, onSaveAlt } = this.args.model;
    const description = data.description?.trim();
    if (this.description && description !== this.description) {
      try {
        await this.postImageCaptionEditor.save(
          context,
          base62Sha1,
          description
        );
      } catch (error) {
        if (this.#isCurrent) {
          popupAjaxError(error);
          return;
        }
      }

      if (!this.#isCurrent) {
        if (!this.isDestroying) {
          this.args.closeModal();
        }
        return;
      }

      this.description = description;
      const message = i18n("discourse_ai.post_image_captions.saved");
      this.toasts.success({ duration: "short", data: { message } });
      this.a11y.announce(message, "polite");
    }

    const nextAlt = normalizeAlt(data.alt);
    if (onSaveAlt && nextAlt !== normalizeAlt(alt)) {
      if (onSaveAlt(nextAlt) === false) {
        this.altSaveFailed = true;
        this.a11y.announce(t("alt_not_updated"), "polite");
        return;
      }
      this.a11y.announce(t("alt_updated"), "polite");
    }

    this.args.closeModal();
  }

  <template>
    {{#let (uniqueId) as |formId|}}
      <DModal
        class="image-descriptions-modal"
        @closeModal={{@closeModal}}
        @title={{t "title"}}
      >
        <:body>
          <Form
            id={{formId}}
            @commitOnSubmit={{false}}
            @data={{this.formData}}
            @onRegisterApi={{this.registerForm}}
            @onSubmit={{this.apply}}
            as |form|
          >
            <div class="image-descriptions-modal__field">
              <form.Field
                @description={{unless @model.onSaveAlt (t "alt_read_only")}}
                @format="full"
                @name="alt"
                @title={{t "alt"}}
                @type="input"
                as |field|
              >
                <field.Control readonly={{not @model.onSaveAlt}} />
              </form.Field>
              {{#if this.altSaveFailed}}
                <p class="image-descriptions-modal__notice">{{t
                    "alt_not_updated"
                  }}</p>
              {{/if}}
            </div>

            <div class="image-descriptions-modal__field">
              {{#if this.description}}
                <form.Field
                  @format="full"
                  @name="description"
                  @title={{t "ai"}}
                  @type="textarea"
                  @validation="required:trim|length:1,1000"
                  as |field|
                >
                  <field.Control maxlength="1000" rows="3" />
                </form.Field>
              {{else}}
                <p class="image-descriptions-modal__label">{{t "ai"}}</p>
                <p
                  class="image-descriptions-modal__notice"
                >{{this.unavailableMessage}}</p>
              {{/if}}
            </div>
          </Form>
        </:body>
        <:footer>
          <DButton
            class="btn-primary"
            @disabled={{this.isLoading}}
            @form={{formId}}
            @isLoading={{this.isApplying}}
            @label="discourse_ai.post_image_captions.image_descriptions.apply"
            @type="submit"
          />
          <DModalCancel @close={{@closeModal}} />
        </:footer>
      </DModal>
    {{/let}}
  </template>
}
