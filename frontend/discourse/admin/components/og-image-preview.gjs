import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class OgImagePreview extends Component {
  @tracked imageUrl = null;
  @tracked loading = false;
  @tracked errorMessage = null;

  formData = { topic_id: "" };

  @action
  async generate(data) {
    if (!data.topic_id) {
      return;
    }
    this.loading = true;
    this.errorMessage = null;
    this.imageUrl = null;
    try {
      const response = await ajax("/admin/config/logo/og-image-preview", {
        type: "GET",
        data: { topic_id: data.topic_id },
      });
      this.imageUrl = response.url;
    } catch (error) {
      this.errorMessage =
        extractError(error) ||
        i18n("admin.config.logo.form.og_image_preview.error");
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div class="og-image-preview">
      <div class="og-image-preview__header">
        <span class="og-image-preview__title">{{i18n
            "admin.config.logo.form.og_image_preview.title"
          }}</span>
      </div>
      <p class="og-image-preview__description">{{i18n
          "admin.config.logo.form.og_image_preview.description"
        }}</p>
      <Form
        @onSubmit={{this.generate}}
        @data={{this.formData}}
        class="og-image-preview__form"
        as |form|
      >
        <div class="og-image-preview__controls">
          <form.Field
            @name="topic_id"
            @title={{i18n
              "admin.config.logo.form.og_image_preview.topic_id_label"
            }}
            @format="small"
            @type="input"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "admin.config.logo.form.og_image_preview.topic_id_placeholder"
              }}
            />
          </form.Field>
          <form.Submit
            @icon="arrows-rotate"
            @label="admin.config.logo.form.og_image_preview.generate"
            @disabled={{this.loading}}
            class="btn-small og-image-preview__generate"
          />
        </div>
      </Form>
      <div class="og-image-preview__frame">
        {{#if this.loading}}
          <div class="og-image-preview__loading">{{i18n "loading"}}</div>
        {{else if this.errorMessage}}
          <div class="og-image-preview__error">{{this.errorMessage}}</div>
        {{else if this.imageUrl}}
          <img
            src={{this.imageUrl}}
            class="og-image-preview__image"
            alt={{i18n "admin.config.logo.form.og_image_preview.title"}}
          />
        {{else}}
          <div class="og-image-preview__placeholder">{{i18n
              "admin.config.logo.form.og_image_preview.placeholder"
            }}</div>
        {{/if}}
      </div>
    </div>
  </template>
}
