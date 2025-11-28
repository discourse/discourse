import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ColorInput from "discourse/admin/components/color-input";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DMultiSelect from "discourse/components/d-multi-select";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import I18n, { i18n } from "discourse-i18n";

export default class AdminWelcomeBannerForm extends Component {
  @service siteSettings;
  @service siteSettingChangeTracker;
  @service toasts;

  @tracked formData = {};
  @tracked isLoading = true;
  @tracked allThemes = [];
  formApi;
  originalFormData = {};

  constructor() {
    super(...arguments);
    this.loadData();
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
    };

    try {
      const response = await ajax("/admin/customize/site_texts.json", {
        data: {
          q: "welcome_banner",
          locale: I18n.currentLocale(),
        },
      });

      const texts = response.site_texts;
      texts.forEach((text) => {
        switch (text.id) {
          case "js.welcome_banner.header.new_members":
            data.headerNewMembers = text.value;
            break;
          case "js.welcome_banner.header.logged_in_members":
            data.headerLoggedInMembers = text.value;
            break;
          case "js.welcome_banner.header.anonymous_members":
            data.headerAnonymousMembers = text.value;
            break;
          case "js.welcome_banner.subheader.logged_in_members":
            data.subheaderLoggedInMembers = text.value;
            break;
          case "js.welcome_banner.subheader.anonymous_members":
            data.subheaderAnonymousMembers = text.value;
            break;
          case "js.welcome_banner.search_placeholder":
            data.searchPlaceholder = text.value;
            break;
        }
      });
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

      const locale = I18n.currentLocale();
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
        duration: 3000,
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
    <ConditionalLoadingSpinner @condition={{this.isLoading}}>
      <Form
        @onSubmit={{this.save}}
        @data={{this.formData}}
        @onRegisterApi={{this.registerApi}}
        class="admin-welcome-banner-form"
        as |form|
      >
        <form.Field
          @name="enabledThemes"
          @title={{i18n
            "admin.config.welcome_banner.form.enabled_themes.label"
          }}
          @description={{i18n
            "admin.config.welcome_banner.form.enabled_themes.description"
          }}
          as |field|
        >
          <field.Custom>
            <DMultiSelect
              @loadFn={{this.loadThemes}}
              @selection={{field.value}}
              @onChange={{field.set}}
            >
              <:selection as |theme|>
                {{theme.name}}
              </:selection>
              <:result as |theme|>
                {{theme.name}}
              </:result>
            </DMultiSelect>
          </field.Custom>
        </form.Field>

        <form.Field
          @name="welcomeBannerImage"
          @title={{i18n
            "admin.config.welcome_banner.form.background_image.label"
          }}
          @description={{i18n
            "admin.config.welcome_banner.form.background_image.description"
          }}
          @onSet={{fn this.handleUpload "welcomeBannerImage"}}
          as |field|
        >
          <field.Image @type="site_setting" />
        </form.Field>

        <form.Field
          @name="welcomeBannerTextColor"
          @title={{i18n "admin.config.welcome_banner.form.text_color.label"}}
          @format="large"
          as |field|
        >
          <field.Custom>
            <ColorInput
              @hexValue={{readonly field.value}}
              @onlyHex={{false}}
              @styleSelection={{false}}
              @onChangeColor={{field.set}}
            />
          </field.Custom>
        </form.Field>

        <form.Field
          @name="welcomeBannerPageVisibility"
          @title={{i18n
            "admin.config.welcome_banner.form.page_visibility.label"
          }}
          @description={{i18n
            "admin.config.welcome_banner.form.page_visibility.description"
          }}
          as |field|
        >
          <field.Select @includeNone={{false}} as |select|>
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
          </field.Select>
        </form.Field>

        <form.Field
          @name="welcomeBannerLocation"
          @title={{i18n "admin.config.welcome_banner.form.location.label"}}
          @description={{i18n
            "admin.config.welcome_banner.form.location.description"
          }}
          as |field|
        >
          <field.Select @includeNone={{false}} as |select|>
            <select.Option @value="above_topic_content">{{i18n
                "admin.config.welcome_banner.form.location.options.above_topic_content"
              }}</select.Option>
            <select.Option @value="below_site_header">{{i18n
                "admin.config.welcome_banner.form.location.options.below_site_header"
              }}</select.Option>
          </field.Select>
        </form.Field>

        <form.Section
          @title={{i18n "admin.config.welcome_banner.form.text_section.title"}}
          @subtitle={{htmlSafe
            (i18n "admin.config.welcome_banner.form.text_section.variables")
          }}
        >

          <form.Field
            @name="headerNewMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.header_new_members.label"
            }}
            @format="large"
            @validation="required"
            as |field|
          >
            <field.Input
              placeholder={{i18n
                "admin.config.welcome_banner.form.header_new_members.placeholder"
                site_name="%{site_name}"
                preferred_display_name="%{preferred_display_name}"
              }}
            />
          </form.Field>

          <form.Field
            @name="headerLoggedInMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.header_logged_in.label"
            }}
            @format="large"
            @validation="required"
            as |field|
          >
            <field.Input
              placeholder={{i18n
                "admin.config.welcome_banner.form.header_logged_in.placeholder"
                preferred_display_name="%{preferred_display_name}"
              }}
            />
          </form.Field>

          <form.Field
            @name="headerAnonymousMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.header_anonymous.label"
            }}
            @format="large"
            @validation="required"
            as |field|
          >
            <field.Input
              placeholder={{i18n
                "admin.config.welcome_banner.form.header_anonymous.placeholder"
                site_name="%{site_name}"
              }}
            />
          </form.Field>

          <form.Field
            @name="subheaderLoggedInMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.subheader_logged_in.label"
            }}
            @description={{i18n
              "admin.config.welcome_banner.form.subheader_logged_in.description"
            }}
            @format="large"
            as |field|
          >
            <field.Textarea />
          </form.Field>

          <form.Field
            @name="subheaderAnonymousMembers"
            @title={{i18n
              "admin.config.welcome_banner.form.subheader_anonymous.label"
            }}
            @description={{i18n
              "admin.config.welcome_banner.form.subheader_anonymous.description"
            }}
            @format="large"
            as |field|
          >
            <field.Textarea />
          </form.Field>

          <form.Field
            @name="searchPlaceholder"
            @title={{i18n
              "admin.config.welcome_banner.form.search_placeholder.label"
            }}
            @description={{i18n
              "admin.config.welcome_banner.form.search_placeholder.description"
            }}
            @format="large"
            @validation="required"
            as |field|
          >
            <field.Input
              placeholder={{i18n
                "admin.config.welcome_banner.form.search_placeholder.placeholder"
              }}
            />
          </form.Field>
        </form.Section>
        <form.Submit />
      </Form>
    </ConditionalLoadingSpinner>
  </template>
}
