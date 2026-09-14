import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import AdminConfigAreaCardSection from "discourse/admin/components/admin-config-area-card-section";
import SimpleList from "discourse/admin/components/simple-list";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import { i18n } from "discourse-i18n";

export default class AdminLogoForm extends Component {
  @service siteSettings;
  @service siteSettingChangeTracker;
  @service toasts;

  @tracked loading = false;
  placeholders = trackedObject();

  constructor() {
    super(...arguments);
    this.#loadPlaceholders();
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

  @action
  handleUpload(type, upload, { set }) {
    if (upload) {
      set(type, getURL(upload.url));
    } else {
      set(type, null);
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

  <template>
    <DConditionalLoadingSpinner @condition={{this.loading}}>
      <Form
        class="admin-logo-form"
        @data={{this.formData}}
        @onSubmit={{this.save}}
        as |form transientData|
      >
        <form.Field
          @description={{i18n "admin.config.logo.form.logo.description"}}
          @helpText={{i18n "admin.config.logo.form.logo.help_text"}}
          @name="logo"
          @onSet={{fn this.handleUpload "logo"}}
          @title={{i18n "admin.config.logo.form.logo.title"}}
          @type="image"
          as |field|
        >
          <field.Control @type="branding" />
        </form.Field>
        <form.Field
          @format="full"
          @name="logo_dark_required"
          @title={{i18n "admin.config.logo.form.logo_dark.required"}}
          @type="toggle"
          as |field|
        >
          <field.Control />
        </form.Field>
        {{#if transientData.logo_dark_required}}
          <form.Section>
            <form.Field
              @helpText={{i18n "admin.config.logo.form.logo_dark.help_text"}}
              @name="logo_dark"
              @onSet={{fn this.handleUpload "logo_dark"}}
              @title={{i18n "admin.config.logo.form.logo_dark.title"}}
              @type="image"
              as |field|
            >
              <field.Control @type="branding" />
            </form.Field>
          </form.Section>
        {{/if}}
        <form.Field
          @description={{i18n "admin.config.logo.form.large_icon.description"}}
          @helpText={{i18n "admin.config.logo.form.large_icon.help_text"}}
          @name="large_icon"
          @onSet={{fn this.handleUpload "large_icon"}}
          @title={{i18n "admin.config.logo.form.large_icon.title"}}
          @type="image"
          as |field|
        >
          <field.Control
            @placeholderUrl={{this.placeholders.large_icon}}
            @type="branding"
          />
        </form.Field>
        <form.Field
          @description={{i18n "admin.config.logo.form.favicon.description"}}
          @name="favicon"
          @onSet={{fn this.handleUpload "favicon"}}
          @title={{i18n "admin.config.logo.form.favicon.title"}}
          @type="image"
          as |field|
        >
          <field.Control
            @placeholderUrl={{this.placeholders.favicon}}
            @type="branding"
          />
        </form.Field>
        <form.Field
          @description={{i18n "admin.config.logo.form.logo_small.description"}}
          @helpText={{i18n "admin.config.logo.form.logo_small.help_text"}}
          @name="logo_small"
          @onSet={{fn this.handleUpload "logo_small"}}
          @title={{i18n "admin.config.logo.form.logo_small.title"}}
          @type="image"
          as |field|
        >
          <field.Control @type="branding" />
        </form.Field>
        <form.Field
          @format="full"
          @name="logo_small_dark_required"
          @title={{i18n "admin.config.logo.form.logo_small_dark.required"}}
          @type="toggle"
          as |field|
        >
          <field.Control />
        </form.Field>
        {{#if transientData.logo_small_dark_required}}
          <form.Section>
            <form.Field
              @helpText={{i18n
                "admin.config.logo.form.logo_small_dark.help_text"
              }}
              @name="logo_small_dark"
              @onSet={{fn this.handleUpload "logo_small_dark"}}
              @title={{i18n "admin.config.logo.form.logo_small_dark.title"}}
              @type="image"
              as |field|
            >
              <field.Control @type="branding" />
            </form.Field>
          </form.Section>
        {{/if}}

        <AdminConfigAreaCardSection
          class="admin-logo-form__mobile-section"
          @collapsable={{true}}
          @collapsed={{true}}
          @heading={{i18n "admin.config.logo.form.mobile"}}
        >

          <:content>
            <form.Field
              @description={{i18n
                "admin.config.logo.form.mobile_logo.description"
              }}
              @helpText={{i18n "admin.config.logo.form.mobile_logo.help_text"}}
              @name="mobile_logo"
              @onSet={{fn this.handleUpload "mobile_logo"}}
              @title={{i18n "admin.config.logo.form.mobile_logo.title"}}
              @type="image"
              as |field|
            >
              <field.Control
                @placeholderUrl={{this.placeholders.mobile_logo}}
                @type="branding"
              />
            </form.Field>
            <form.Field
              @format="full"
              @name="mobile_logo_dark_required"
              @title={{i18n "admin.config.logo.form.mobile_logo_dark.required"}}
              @type="toggle"
              as |field|
            >
              <field.Control />
            </form.Field>
            {{#if transientData.mobile_logo_dark_required}}
              <form.Section>
                <form.Field
                  @helpText={{i18n
                    "admin.config.logo.form.mobile_logo_dark.help_text"
                  }}
                  @name="mobile_logo_dark"
                  @onSet={{fn this.handleUpload "mobile_logo_dark"}}
                  @title={{i18n
                    "admin.config.logo.form.mobile_logo_dark.title"
                  }}
                  @type="image"
                  as |field|
                >
                  <field.Control @type="branding" />
                </form.Field>
              </form.Section>
            {{/if}}
            <form.Field
              @description={{i18n
                "admin.config.logo.form.manifest_icon.description"
              }}
              @helpText={{i18n
                "admin.config.logo.form.manifest_icon.help_text"
              }}
              @name="manifest_icon"
              @onSet={{fn this.handleUpload "manifest_icon"}}
              @title={{i18n "admin.config.logo.form.manifest_icon.title"}}
              @type="image"
              as |field|
            >
              <field.Control @type="branding" />
            </form.Field>
            <form.Field
              @description={{i18n
                "admin.config.logo.form.manifest_screenshots.description"
              }}
              @format="full"
              @name="manifest_screenshots"
              @title={{i18n
                "admin.config.logo.form.manifest_screenshots.title"
              }}
              @type="custom"
              as |field|
            >
              <field.Control>
                <SimpleList
                  id={{field.id}}
                  @allowAny={{true}}
                  @inputDelimiter="|"
                  @onChange={{fn this.updateManifestScreenshots field}}
                  @values={{field.value}}
                />
              </field.Control>
            </form.Field>
            <form.Field
              @description={{i18n
                "admin.config.logo.form.apple_touch_icon.description"
              }}
              @helpText={{i18n
                "admin.config.logo.form.apple_touch_icon.help_text"
              }}
              @name="apple_touch_icon"
              @onSet={{fn this.handleUpload "apple_touch_icon"}}
              @title={{i18n "admin.config.logo.form.apple_touch_icon.title"}}
              @type="image"
              as |field|
            >
              <field.Control
                @placeholderUrl={{this.placeholders.apple_touch_icon}}
                @type="branding"
              />
            </form.Field>
          </:content>
        </AdminConfigAreaCardSection>
        <AdminConfigAreaCardSection
          class="admin-logo-form__email-section"
          @collapsable={{true}}
          @collapsed={{true}}
          @heading={{i18n "admin.config.logo.form.email"}}
        >
          <:content>
            <form.Field
              @description={{i18n
                "admin.config.logo.form.digest_logo.description"
              }}
              @helpText={{i18n "admin.config.logo.form.digest_logo.help_text"}}
              @name="digest_logo"
              @onSet={{fn this.handleUpload "digest_logo"}}
              @title={{i18n "admin.config.logo.form.digest_logo.title"}}
              @type="image"
              as |field|
            >
              <field.Control
                @placeholderUrl={{this.placeholders.digest_logo}}
                @type="branding"
              />
            </form.Field>
          </:content>
        </AdminConfigAreaCardSection>
        <AdminConfigAreaCardSection
          class="admin-logo-form__social-media-section"
          @collapsable={{true}}
          @collapsed={{true}}
          @heading={{i18n "admin.config.logo.form.social_media"}}
        >
          <:content>
            <form.Field
              @description={{i18n
                "admin.config.logo.form.opengraph_image.description"
              }}
              @name="opengraph_image"
              @onSet={{fn this.handleUpload "opengraph_image"}}
              @title={{i18n "admin.config.logo.form.opengraph_image.title"}}
              @type="image"
              as |field|
            >
              <field.Control
                @placeholderUrl={{this.placeholders.opengraph_image}}
                @type="branding"
              />
            </form.Field>
          </:content>
        </AdminConfigAreaCardSection>
        <form.Submit />
      </Form>
    </DConditionalLoadingSpinner>
  </template>
}
