import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCardSection from "admin/components/admin-config-area-card-section";
import SimpleList from "admin/components/simple-list";

export default class AdminLogoForm extends Component {
  @service siteSettings;
  @service siteSettingChangeTracker;
  @service toasts;

  @tracked placeholders = {};
  @tracked loading = false;

  constructor() {
    super(...arguments);
    this.#loadPlaceholders();
  }

  @bind
  async #loadPlaceholders() {
    this.loading = true;
    try {
      const result = await ajax("/admin/config/site_settings.json", {
        data: {
          categories: ["branding"],
        },
      });

      result.site_settings.forEach((setting) => {
        if (setting.placeholder) {
          this.placeholders[setting.setting] = setting.placeholder;
        }
      });
    } finally {
      this.loading = false;
    }
  }

  @action
  handleUpload(type, upload, { set }) {
    if (upload) {
      set(type, getURL(upload.url));
    } else {
      set(type, undefined);
    }
  }

  @action
  async save(data) {
    try {
      await ajax("/admin/config/logo.json", {
        type: "PUT",
        data: {
          logo: data.logo,
          logo_dark: data.logo_dark,
          large_icon: data.large_icon,
          favicon: data.favicon,
          logo_small: data.logo_small,
          logo_small_dark: data.logo_small_dark,
          mobile_logo: data.mobile_logo,
          mobile_logo_dark: data.mobile_logo_dark,
          manifest_icon: data.manifest_icon,
          manifest_screenshots: data.manifest_screenshots,
          apple_touch_icon: data.apple_touch_icon,
          digest_logo: data.digest_logo,
          opengraph_image: data.opengraph_image,
          x_summary_large_image: data.x_summary_large_image,
        },
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin.config.logo.form.saved"),
        },
      });
      this.siteSettingChangeTracker.refreshPage(data);
    } catch (err) {
      this.toasts.error({
        duration: "short",
        data: {
          message: err.jqXHR.responseJSON.errors[0],
        },
      });
    }
  }

  @action
  updateManifestScreenshots(field, selected) {
    field.set(selected.join("|"));
  }

  @cached
  get formData() {
    return {
      logo: this.siteSettings.logo,
      logo_dark_required: !!this.siteSettings.logo_dark,
      logo_dark: this.siteSettings.logo_dark,
      large_icon: this.siteSettings.large_icon,
      favicon: this.siteSettings.favicon,
      logo_small: this.siteSettings.logo_small,
      logo_small_dark_required: !!this.siteSettings.logo_small_dark,
      logo_small_dark: this.siteSettings.logo_small_dark,
      mobile_logo: this.siteSettings.mobile_logo,
      mobile_logo_dark_required: !!this.siteSettings.mobile_logo_dark,
      mobile_logo_dark: this.siteSettings.mobile_logo_dark,
      manifest_icon: this.siteSettings.manifest_icon,
      manifest_screenshots: this.siteSettings.manifest_screenshots,
      apple_touch_icon: this.siteSettings.apple_touch_icon,
      digest_logo: this.siteSettings.digest_logo,
      opengraph_image: this.siteSettings.opengraph_image,
      x_summary_large_image: this.siteSettings.x_summary_large_image,
    };
  }

  <template>
    <ConditionalLoadingSpinner @condition={{this.loading}}>
      <Form
        @onSubmit={{this.save}}
        @data={{this.formData}}
        class="admin-logo-form"
        as |form transientData|
      >
        <form.Field
          @name="logo"
          @title={{i18n "admin.config.logo.form.logo.title"}}
          @description={{i18n "admin.config.logo.form.logo.description"}}
          @helpText={{i18n "admin.config.logo.form.logo.help_text"}}
          @onSet={{fn this.handleUpload "logo"}}
          as |field|
        >
          <field.Image @type="branding" />
        </form.Field>
        <form.Field
          @name="logo_dark_required"
          @title={{i18n "admin.config.logo.form.logo_dark.required"}}
          @format="full"
          as |field|
        >
          <field.Toggle />
        </form.Field>
        {{#if transientData.logo_dark_required}}
          <form.Section>
            <form.Field
              @name="logo_dark"
              @title={{i18n "admin.config.logo.form.logo_dark.title"}}
              @helpText={{i18n "admin.config.logo.form.logo_dark.help_text"}}
              @onSet={{fn this.handleUpload "logo_dark"}}
              as |field|
            >
              <field.Image @type="branding" />
            </form.Field>
          </form.Section>
        {{/if}}
        <form.Field
          @name="large_icon"
          @title={{i18n "admin.config.logo.form.large_icon.title"}}
          @description={{i18n "admin.config.logo.form.large_icon.description"}}
          @helpText={{i18n "admin.config.logo.form.large_icon.help_text"}}
          @onSet={{fn this.handleUpload "large_icon"}}
          @placeholderUrl={{this.placeholders.large_icon}}
          as |field|
        >
          <field.Image @type="branding" />
        </form.Field>
        <form.Field
          @name="favicon"
          @title={{i18n "admin.config.logo.form.favicon.title"}}
          @description={{i18n "admin.config.logo.form.favicon.description"}}
          @onSet={{fn this.handleUpload "favicon"}}
          @placeholderUrl={{this.placeholders.favicon}}
          as |field|
        >
          <field.Image @type="branding" />
        </form.Field>
        <form.Field
          @name="logo_small"
          @title={{i18n "admin.config.logo.form.logo_small.title"}}
          @description={{i18n "admin.config.logo.form.logo_small.description"}}
          @helpText={{i18n "admin.config.logo.form.logo_small.help_text"}}
          @onSet={{fn this.handleUpload "logo_small"}}
          as |field|
        >
          <field.Image @type="branding" />
        </form.Field>
        <form.Field
          @name="logo_small_dark_required"
          @title={{i18n "admin.config.logo.form.logo_small_dark.required"}}
          @format="full"
          as |field|
        >
          <field.Toggle />
        </form.Field>
        {{#if transientData.logo_small_dark_required}}
          <form.Section>
            <form.Field
              @name="logo_small_dark"
              @title={{i18n "admin.config.logo.form.logo_small_dark.title"}}
              @helpText={{i18n
                "admin.config.logo.form.logo_small_dark.help_text"
              }}
              @onSet={{fn this.handleUpload "logo_small_dark"}}
              as |field|
            >
              <field.Image @type="branding" />
            </form.Field>
          </form.Section>
        {{/if}}

        <AdminConfigAreaCardSection
          @heading={{i18n "admin.config.logo.form.mobile"}}
          class="admin-logo-form__mobile-section"
          @collapsable={{true}}
          @collapsed={{true}}
        >
          <:content>
            <form.Field
              @name="mobile_logo"
              @title={{i18n "admin.config.logo.form.mobile_logo.title"}}
              @description={{i18n
                "admin.config.logo.form.mobile_logo.description"
              }}
              @helpText={{i18n "admin.config.logo.form.mobile_logo.help_text"}}
              @onSet={{fn this.handleUpload "mobile_logo"}}
              @placeholderUrl={{this.placeholders.mobile_logo}}
              as |field|
            >
              <field.Image @type="branding" />
            </form.Field>
            <form.Field
              @name="mobile_logo_dark_required"
              @title={{i18n "admin.config.logo.form.mobile_logo_dark.required"}}
              @format="full"
              as |field|
            >
              <field.Toggle />
            </form.Field>
            {{#if transientData.mobile_logo_dark_required}}
              <form.Section>
                <form.Field
                  @name="mobile_logo_dark"
                  @title={{i18n
                    "admin.config.logo.form.mobile_logo_dark.title"
                  }}
                  @helpText={{i18n
                    "admin.config.logo.form.mobile_logo_dark.help_text"
                  }}
                  @onSet={{fn this.handleUpload "mobile_logo_dark"}}
                  as |field|
                >
                  <field.Image @type="branding" />
                </form.Field>
              </form.Section>
            {{/if}}
            <form.Field
              @name="manifest_icon"
              @title={{i18n "admin.config.logo.form.manifest_icon.title"}}
              @description={{i18n
                "admin.config.logo.form.manifest_icon.description"
              }}
              @helpText={{i18n
                "admin.config.logo.form.manifest_icon.help_text"
              }}
              @onSet={{fn this.handleUpload "manifest_icon"}}
              as |field|
            >
              <field.Image @type="branding" />
            </form.Field>
            <form.Field
              @name="manifest_screenshots"
              @title={{i18n
                "admin.config.logo.form.manifest_screenshots.title"
              }}
              @description={{i18n
                "admin.config.logo.form.manifest_screenshots.description"
              }}
              @format="full"
              as |field|
            >
              <field.Custom>
                <SimpleList
                  @id={{field.id}}
                  @onChange={{fn this.updateManifestScreenshots field}}
                  @inputDelimiter="|"
                  @values={{field.value}}
                  @allowAny={{true}}
                />
              </field.Custom>
            </form.Field>
            <form.Field
              @name="apple_touch_icon"
              @title={{i18n "admin.config.logo.form.apple_touch_icon.title"}}
              @description={{i18n
                "admin.config.logo.form.apple_touch_icon.description"
              }}
              @helpText={{i18n
                "admin.config.logo.form.apple_touch_icon.help_text"
              }}
              @onSet={{fn this.handleUpload "apple_touch_icon"}}
              @placeholderUrl={{this.placeholders.apple_touch_icon}}
              as |field|
            >
              <field.Image @type="branding" />
            </form.Field>
          </:content>
        </AdminConfigAreaCardSection>
        <AdminConfigAreaCardSection
          @heading={{i18n "admin.config.logo.form.email"}}
          class="admin-logo-form__email-section"
          @collapsable={{true}}
          @collapsed={{true}}
        >
          <:content>
            <form.Field
              @name="digest_logo"
              @title={{i18n "admin.config.logo.form.digest_logo.title"}}
              @description={{i18n
                "admin.config.logo.form.digest_logo.description"
              }}
              @helpText={{i18n "admin.config.logo.form.digest_logo.help_text"}}
              @onSet={{fn this.handleUpload "digest_logo"}}
              @placeholderUrl={{this.placeholders.digest_logo}}
              as |field|
            >
              <field.Image
                @type="branding"
                @placeholderUrl={{this.placeholders.digest_logo}}
              />
            </form.Field>
          </:content>
        </AdminConfigAreaCardSection>
        <AdminConfigAreaCardSection
          @heading={{i18n "admin.config.logo.form.social_media"}}
          class="admin-logo-form__social-media-section"
          @collapsable={{true}}
          @collapsed={{true}}
        >
          <:content>
            <form.Field
              @name="opengraph_image"
              @title={{i18n "admin.config.logo.form.opengraph_image.title"}}
              @description={{i18n
                "admin.config.logo.form.opengraph_image.description"
              }}
              @onSet={{fn this.handleUpload "opengraph_image"}}
              @placeholderUrl={{this.placeholders.opengraph_image}}
              as |field|
            >
              <field.Image @type="branding" />
            </form.Field>
          </:content>
        </AdminConfigAreaCardSection>
        <form.Submit />
      </Form>
    </ConditionalLoadingSpinner>
  </template>
}
