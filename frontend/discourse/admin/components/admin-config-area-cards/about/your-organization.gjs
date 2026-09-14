import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasAboutYourOrganization extends Component {
  @service toasts;

  @cached
  get data() {
    return {
      companyName: this.#settingValue(
        "company_name",
        this.args.yourOrganization.companyName
      ),
      companyURL: this.#settingValue(
        "company_url",
        this.args.yourOrganization.companyURL
      ),
      governingLaw: this.#settingValue(
        "governing_law",
        this.args.yourOrganization.governingLaw
      ),
      cityForDisputes: this.#settingValue(
        "city_for_disputes",
        this.args.yourOrganization.cityForDisputes
      ),
    };
  }

  get #savePath() {
    if (this.args.isDefaultLocale) {
      return "/admin/config/about.json";
    }

    return "/admin/config/about/localizations.json";
  }

  @action
  async save(data) {
    this.args.setGlobalSavingStatus(true);
    try {
      await ajax(this.#savePath, {
        type: "PUT",
        data: {
          locale: this.args.locale,
          your_organization: {
            company_name: data.companyName,
            company_url: data.companyURL,
            governing_law: data.governingLaw,
            city_for_disputes: data.cityForDisputes,
          },
        },
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "admin.config_areas.about.toasts.your_organization_saved"
          ),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.args.setGlobalSavingStatus(false);
    }
  }

  #settingValue(settingName, setting) {
    if (this.args.isDefaultLocale) {
      return setting.value;
    }

    return this.args.localizations?.[settingName]?.value ?? "";
  }

  <template>
    <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @format="large"
        @name="companyName"
        @title={{i18n "admin.config_areas.about.company_name"}}
        @type="input"
        as |field|
      >
        <field.Control
          placeholder={{i18n
            "admin.config_areas.about.company_name_placeholder"
          }}
        />
      </form.Field>
      <form.Alert @type="info">
        {{i18n "admin.config_areas.about.company_name_warning"}}
      </form.Alert>

      <form.Field
        @format="large"
        @name="companyURL"
        @title={{i18n "admin.config_areas.about.company_url"}}
        @type="input-url"
        as |field|
      >
        <field.Control
          placeholder={{i18n
            "admin.config_areas.about.company_url_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @description={{i18n "admin.config_areas.about.governing_law_help"}}
        @format="large"
        @name="governingLaw"
        @title={{i18n "admin.config_areas.about.governing_law"}}
        @type="input"
        as |field|
      >
        <field.Control
          placeholder={{i18n
            "admin.config_areas.about.governing_law_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @description={{i18n "admin.config_areas.about.city_for_disputes_help"}}
        @format="large"
        @name="cityForDisputes"
        @title={{i18n "admin.config_areas.about.city_for_disputes"}}
        @type="input"
        as |field|
      >
        <field.Control
          placeholder={{i18n
            "admin.config_areas.about.city_for_disputes_placeholder"
          }}
        />
      </form.Field>

      <form.Submit
        @disabled={{@globalSavingStatus}}
        @label="admin.config_areas.about.update"
      />
    </Form>
  </template>
}
