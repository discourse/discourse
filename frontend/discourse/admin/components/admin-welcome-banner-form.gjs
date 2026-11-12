import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import ComboBox from "discourse/select-kit/components/combo-box";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import I18n, { i18n } from "discourse-i18n";

export default class AdminWelcomeBannerForm extends Component {
  @service siteSettings;
  @service siteSettingChangeTracker;
  @service toasts;

  @tracked formData = {};
  @tracked isLoading = true;
  @tracked isLoadingLocale = false;
  @tracked allThemes = [];
  @tracked locale;
  formApi;
  originalFormData = {};

  constructor() {
    super(...arguments);
    this.locale = I18n.currentLocale();
    this.loadData();
  }

  get availableLocales() {
    return this.siteSettings.available_locales;
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  handleUpload(fieldName, upload, { set }) {
    if (upload) {
      set(fieldName, getURL(upload.url));
    } else {
      set(fieldName, undefined);
    }
  }

  async loadData() {
    await this.loadSettings();
    await this.loadThemesWithSettings();
    this.isLoading = false;
  }

  async loadSettings() {
    const data = {
      welcomeBannerImage: this.siteSettings.welcome_banner_image,
      welcomeBannerTextColor: this.siteSettings.welcome_banner_text_color,
      welcomeBannerLocation: this.siteSettings.welcome_banner_location,
      welcomeBannerPageVisibility:
        this.siteSettings.welcome_banner_page_visibility,
      enabledThemes: [],
      localeSelector: this.locale,
    };

    try {
      const textData = await this.fetchSiteTexts(this.locale);
      Object.assign(data, textData);
    } catch (error) {
      popupAjaxError(error);
    }

    this.formData = data;
    this.originalFormData = { ...data };
  }

  async loadThemesWithSettings() {
    try {
      const response = await ajax(
        "/admin/config/welcome-banner/themes-with-setting.json"
      );

      this.allThemes = response.themes.map((themeData) => ({
        id: themeData.id,
        name: themeData.name,
        enable_welcome_banner: themeData.enable_welcome_banner,
      }));

      const enabledThemes = this.allThemes.filter(
        (theme) => theme.enable_welcome_banner
      );

      this.formData = {
        ...this.formData,
        enabledThemes,
      };
      this.originalFormData = {
        ...this.originalFormData,
        enabledThemes,
      };
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async loadThemes(filter) {
    if (!filter) {
      return this.allThemes;
    }
    return this.allThemes.filter((theme) =>
      theme.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  async fetchSiteTexts(locale) {
    const keys = [
      "js.welcome_banner.header.new_members",
      "js.welcome_banner.header.logged_in_members",
      "js.welcome_banner.header.anonymous_members",
      "js.welcome_banner.subheader.logged_in_members",
      "js.welcome_banner.subheader.anonymous_members",
      "js.welcome_banner.search_placeholder",
    ];

    const responses = await Promise.all(
      keys.map((key) =>
        ajax(`/admin/customize/site_texts/${key}.json`, {
          data: { locale },
        }).catch(() => ({ site_text: { id: key, value: "" } }))
      )
    );

    const textData = {};
    responses.forEach((response) => {
      const text = response.site_text;
      switch (text.id) {
        case "js.welcome_banner.header.new_members":
          textData.headerNewMembers = text.value;
          break;
        case "js.welcome_banner.header.logged_in_members":
          textData.headerLoggedInMembers = text.value;
          break;
        case "js.welcome_banner.header.anonymous_members":
          textData.headerAnonymousMembers = text.value;
          break;
        case "js.welcome_banner.subheader.logged_in_members":
          textData.subheaderLoggedInMembers = text.value;
          break;
        case "js.welcome_banner.subheader.anonymous_members":
          textData.subheaderAnonymousMembers = text.value;
          break;
        case "js.welcome_banner.search_placeholder":
          textData.searchPlaceholder = text.value;
          break;
      }
    });

    return textData;
  }

  @action
  async updateLocale(localeValue) {
    this.isLoadingLocale = true;
    this.locale = localeValue;

    try {
      const textData = await this.fetchSiteTexts(this.locale);

      // don't reset entire form on language switch, just update relevant fields
      if (this.formApi) {
        Object.entries(textData).forEach(([key, value]) => {
          this.formApi.set(key, value);
        });
        this.formApi.set("localeSelector", localeValue);
      } else {
        this.formData = {
          ...this.formData,
          ...textData,
          localeSelector: localeValue,
        };
      }

      // Update originalFormData so save() correctly detects changes for the new locale
      this.originalFormData = {
        ...this.originalFormData,
        ...textData,
        localeSelector: localeValue,
      };
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoadingLocale = false;
    }
  }

  @action
  async save(data) {
    let siteTextsChanged = false;

    try {
      if (
        data.welcomeBannerImage !== this.originalFormData.welcomeBannerImage
      ) {
        await ajax("/admin/site_settings/welcome_banner_image", {
          type: "PUT",
          data: { welcome_banner_image: data.welcomeBannerImage || "" },
        });
      }

      if (
        data.welcomeBannerTextColor !==
        this.originalFormData.welcomeBannerTextColor
      ) {
        await ajax("/admin/site_settings/welcome_banner_text_color", {
          type: "PUT",
          data: {
            welcome_banner_text_color: data.welcomeBannerTextColor || "",
          },
        });
      }

      if (
        data.welcomeBannerLocation !==
        this.originalFormData.welcomeBannerLocation
      ) {
        await ajax("/admin/site_settings/welcome_banner_location", {
          type: "PUT",
          data: { welcome_banner_location: data.welcomeBannerLocation },
        });
      }

      if (
        data.welcomeBannerPageVisibility !==
        this.originalFormData.welcomeBannerPageVisibility
      ) {
        await ajax("/admin/site_settings/welcome_banner_page_visibility", {
          type: "PUT",
          data: {
            welcome_banner_page_visibility: data.welcomeBannerPageVisibility,
          },
        });
      }

      const locale = this.locale;
      const siteTextUpdates = [
        {
          id: "js.welcome_banner.header.new_members",
          value: data.headerNewMembers,
        },
        {
          id: "js.welcome_banner.header.logged_in_members",
          value: data.headerLoggedInMembers,
        },
        {
          id: "js.welcome_banner.header.anonymous_members",
          value: data.headerAnonymousMembers,
        },
        {
          id: "js.welcome_banner.subheader.logged_in_members",
          value: data.subheaderLoggedInMembers,
        },
        {
          id: "js.welcome_banner.subheader.anonymous_members",
          value: data.subheaderAnonymousMembers,
        },
        {
          id: "js.welcome_banner.search_placeholder",
          value: data.searchPlaceholder,
        },
      ];

      const originalTextValues = {
        "js.welcome_banner.header.new_members":
          this.originalFormData.headerNewMembers,
        "js.welcome_banner.header.logged_in_members":
          this.originalFormData.headerLoggedInMembers,
        "js.welcome_banner.header.anonymous_members":
          this.originalFormData.headerAnonymousMembers,
        "js.welcome_banner.subheader.logged_in_members":
          this.originalFormData.subheaderLoggedInMembers,
        "js.welcome_banner.subheader.anonymous_members":
          this.originalFormData.subheaderAnonymousMembers,
        "js.welcome_banner.search_placeholder":
          this.originalFormData.searchPlaceholder,
      };

      for (const text of siteTextUpdates) {
        const originalValue = originalTextValues[text.id] || "";
        const newValue = text.value || "";

        if (newValue !== originalValue) {
          if (!newValue || newValue.trim() === "") {
            await ajax(
              `/admin/customize/site_texts/${text.id}?locale=${locale}`,
              {
                type: "DELETE",
              }
            );
          } else {
            await ajax(
              `/admin/customize/site_texts/${text.id}?locale=${locale}`,
              {
                type: "PUT",
                data: {
                  site_text: {
                    value: newValue,
                    locale,
                  },
                },
              }
            );
          }
          siteTextsChanged = true;
        }
      }

      await Promise.allSettled(
        this.allThemes.map((theme) => {
          const shouldBeEnabled = data.enabledThemes.some(
            (t) => t.id === theme.id
          );

          return ajax(`/admin/themes/${theme.id}/site-setting`, {
            type: "PUT",
            data: {
              name: "enable_welcome_banner",
              value: shouldBeEnabled,
            },
          });
        })
      );

      this.originalFormData = { ...data };

      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin.config.welcome_banner.saved"),
        },
      });

      if (siteTextsChanged) {
        this.siteSettingChangeTracker.refreshPage({
          welcome_banner_image: data.welcomeBannerImage,
          welcome_banner_text_color: data.welcomeBannerTextColor,
          welcome_banner_location: data.welcomeBannerLocation,
          welcome_banner_page_visibility: data.welcomeBannerPageVisibility,
        });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DConditionalLoadingSpinner @condition={{this.isLoading}}>
      <Form
        class="admin-welcome-banner-form"
        @data={{this.formData}}
        @onRegisterApi={{this.registerApi}}
        @onSubmit={{this.save}}
        as |form|
      >
        <form.Field
          @description={{i18n
            "admin.config.welcome_banner.form.enabled_themes.description"
          }}
          @format="large"
          @name="enabledThemes"
          @title={{i18n
            "admin.config.welcome_banner.form.enabled_themes.label"
          }}
          @type="custom"
          as |field|
        >
          <field.Control>
            <DMultiSelect
              @label={{i18n
                "admin.config.welcome_banner.form.enabled_themes.select_label"
              }}
              @loadFn={{this.loadThemes}}
              @onChange={{field.set}}
              @selection={{field.value}}
            >
              <:selection as |theme|>
                {{theme.name}}
              </:selection>
              <:result as |theme|>
                {{theme.name}}
              </:result>
            </DMultiSelect>
          </field.Control>
        </form.Field>

        <form.Field
          @description={{i18n
            "admin.config.welcome_banner.form.background_image.description"
          }}
          @name="welcomeBannerImage"
          @onSet={{fn this.handleUpload "welcomeBannerImage"}}
          @title={{i18n
            "admin.config.welcome_banner.form.background_image.label"
          }}
          @type="image"
          as |field|
        >
          <field.Control @type="site_setting" />
        </form.Field>

        <form.Field
          @description={{i18n
            "admin.config.welcome_banner.form.text_color.description"
          }}
          @format="large"
          @name="welcomeBannerTextColor"
          @title={{i18n "admin.config.welcome_banner.form.text_color.label"}}
          @type="color"
          as |field|
        >
          <field.Control @allowNamedColors={{true}} @prefixHex={{true}} />
        </form.Field>

        <form.Field
          @description={{i18n
            "admin.config.welcome_banner.form.page_visibility.description"
          }}
          @name="welcomeBannerPageVisibility"
          @title={{i18n
            "admin.config.welcome_banner.form.page_visibility.label"
          }}
          @type="select"
          as |field|
        >
          <field.Control @includeNone={{false}} as |select|>
            <select.Option @value="top_menu_pages">{{i18n
                "admin.config.welcome_banner.form.page_visibility.options.top_menu_pages"
              }}</select.Option>
            <select.Option @value="homepage">{{i18n
                "admin.config.welcome_banner.form.page_visibility.options.homepage"
              }}</select.Option>
            <select.Option @value="discovery">{{i18n
                "admin.config.welcome_banner.form.page_visibility.options.discovery"
              }}</select.Option>
            <select.Option @value="all_pages">{{i18n
                "admin.config.welcome_banner.form.page_visibility.options.all_pages"
              }}</select.Option>
          </field.Control>
        </form.Field>

        <form.Field
          @description={{i18n
            "admin.config.welcome_banner.form.location.description"
          }}
          @name="welcomeBannerLocation"
          @title={{i18n "admin.config.welcome_banner.form.location.label"}}
          @type="select"
          as |field|
        >
          <field.Control @includeNone={{false}} as |select|>
            <select.Option @value="above_topic_content">{{i18n
                "admin.config.welcome_banner.form.location.options.above_topic_content"
              }}</select.Option>
            <select.Option @value="below_site_header">{{i18n
                "admin.config.welcome_banner.form.location.options.below_site_header"
              }}</select.Option>
          </field.Control>
        </form.Field>

        <form.Section
          @title={{i18n "admin.config.welcome_banner.form.text_section.title"}}
        >
          <form.Field
            @format="large"
            @name="localeSelector"
            @title={{i18n
              "admin.config.welcome_banner.form.text_section.locale_label"
            }}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <ComboBox
                class="translation-selector"
                @content={{this.availableLocales}}
                @onChange={{this.updateLocale}}
                @options={{hash filterable=true}}
                @value={{this.locale}}
                @valueProperty="value"
              />
            </field.Control>
          </form.Field>

          <form.Field
            @description={{trustHTML
              (i18n
                "admin.config.welcome_banner.form.header_new_members.description"
              )
            }}
            @disabled={{this.isLoadingLocale}}
            @format="large"
            @name="headerNewMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.header_new_members.label"
            }}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "admin.config.welcome_banner.form.header_new_members.placeholder"
                site_name="%{site_name}"
                preferred_display_name="%{preferred_display_name}"
              }}
            />
          </form.Field>

          <form.Field
            @description={{trustHTML
              (i18n
                "admin.config.welcome_banner.form.header_logged_in.description"
              )
            }}
            @disabled={{this.isLoadingLocale}}
            @format="large"
            @name="headerLoggedInMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.header_logged_in.label"
            }}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "admin.config.welcome_banner.form.header_logged_in.placeholder"
                site_name="%{site_name}"
                preferred_display_name="%{preferred_display_name}"
              }}
            />
          </form.Field>

          <form.Field
            @description={{trustHTML
              (i18n
                "admin.config.welcome_banner.form.header_anonymous.description"
              )
            }}
            @disabled={{this.isLoadingLocale}}
            @format="large"
            @name="headerAnonymousMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.header_anonymous.label"
            }}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "admin.config.welcome_banner.form.header_anonymous.placeholder"
                site_name="%{site_name}"
              }}
            />
          </form.Field>

          <form.Field
            @description={{i18n
              "admin.config.welcome_banner.form.subheader_logged_in.description"
            }}
            @disabled={{this.isLoadingLocale}}
            @format="large"
            @name="subheaderLoggedInMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.subheader_logged_in.label"
            }}
            @type="textarea"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Field
            @description={{i18n
              "admin.config.welcome_banner.form.subheader_anonymous.description"
            }}
            @disabled={{this.isLoadingLocale}}
            @format="large"
            @name="subheaderAnonymousMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.subheader_anonymous.label"
            }}
            @type="textarea"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Field
            @description={{i18n
              "admin.config.welcome_banner.form.search_placeholder.description"
            }}
            @disabled={{this.isLoadingLocale}}
            @format="large"
            @name="searchPlaceholder"
            @title={{i18n
              "admin.config.welcome_banner.form.search_placeholder.label"
            }}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control
              placeholder={{i18n
                "admin.config.welcome_banner.form.search_placeholder.placeholder"
              }}
            />
          </form.Field>
        </form.Section>
        <form.Submit />
      </Form>
    </DConditionalLoadingSpinner>
  </template>
}
