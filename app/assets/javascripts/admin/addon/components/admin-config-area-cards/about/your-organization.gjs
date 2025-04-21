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

  companyName = this.args.yourOrganization.companyName.value;
  governingLaw = this.args.yourOrganization.governingLaw.value;
  cityForDisputes = this.args.yourOrganization.cityForDisputes.value;

  @cached
  get data() {
    return {
      companyName: this.args.yourOrganization.companyName.value,
      governingLaw: this.args.yourOrganization.governingLaw.value,
      cityForDisputes: this.args.yourOrganization.cityForDisputes.value,
    };
  }

  @action
  async save(data) {
    this.args.setGlobalSavingStatus(true);
    try {
      await ajax("/admin/config/about.json", {
        type: "PUT",
        data: {
          your_organization: {
            company_name: data.companyName,
            governing_law: data.governingLaw,
            city_for_disputes: data.cityForDisputes,
          },
        },
      });
      this.toasts.success({
        duration: 30000,
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

  <template>
    <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @name="companyName"
        @title={{i18n "admin.config_areas.about.company_name"}}
        @format="large"
        as |field|
      >
        <field.Input
          placeholder={{i18n
            "admin.config_areas.about.company_name_placeholder"
          }}
        />
      </form.Field>
      <form.Alert @type="info">
        {{i18n "admin.config_areas.about.company_name_warning"}}
      </form.Alert>

      <form.Field
        @name="governingLaw"
        @title={{i18n "admin.config_areas.about.governing_law"}}
        @description={{i18n "admin.config_areas.about.governing_law_help"}}
        @format="large"
        as |field|
      >
        <field.Input
          placeholder={{i18n
            "admin.config_areas.about.governing_law_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @name="cityForDisputes"
        @title={{i18n "admin.config_areas.about.city_for_disputes"}}
        @description={{i18n "admin.config_areas.about.city_for_disputes_help"}}
        @format="large"
        as |field|
      >
        <field.Input
          placeholder={{i18n
            "admin.config_areas.about.city_for_disputes_placeholder"
          }}
        />
      </form.Field>

      <form.Submit
        @label="admin.config_areas.about.update"
        @disabled={{@globalSavingStatus}}
      />
    </Form>
  </template>
}
