import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasAboutContactInformation extends Component {
  @service site;
  @service toasts;

  @tracked
  contactGroupId = this.site.groups.find(
    (group) => group.name === this.data.contactGroupName
  )?.id;

  @cached
  get data() {
    return {
      communityOwner: this.#settingValue(
        "community_owner",
        this.args.contactInformation.communityOwner
      ),
      contactEmail: this.args.contactInformation.contactEmail.value,
      contactURL: this.args.contactInformation.contactURL.value,
      contactGroupName: this.args.contactInformation.contactGroupName.value,
      contactUsername:
        this.args.contactInformation.contactUsername.value || null,
    };
  }

  @action
  setContactUsername(usernames, { set }) {
    set("contactUsername", usernames[0] || null);
  }

  @action
  setContactGroup(groupIds, { set }) {
    this.contactGroupId = groupIds[0];
    set("contactGroupName", this.site.groupsById[groupIds[0]]?.name);
  }

  @action
  async save(data) {
    try {
      this.args.setGlobalSavingStatus(true);
      await ajax(this.#savePath, {
        type: "PUT",
        data: this.#saveData(data),
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "admin.config_areas.about.toasts.contact_information_saved"
          ),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.args.setGlobalSavingStatus(false);
    }
  }

  get #savePath() {
    if (this.args.isDefaultLocale) {
      return "/admin/config/about.json";
    }

    return "/admin/config/about/localizations.json";
  }

  #saveData(data) {
    const payload = {
      locale: this.args.locale,
      contact_information: {
        community_owner: data.communityOwner,
      },
    };

    if (this.args.isDefaultLocale) {
      payload.contact_information.contact_email = data.contactEmail;
      payload.contact_information.contact_url = data.contactURL;
      payload.contact_information.contact_username = data.contactUsername;
      payload.contact_information.contact_group_name = data.contactGroupName;
    }

    return payload;
  }

  #settingValue(settingName, setting) {
    if (this.args.isDefaultLocale) {
      return setting.value;
    }

    return this.args.localizations?.[settingName]?.value ?? setting.value;
  }

  <template>
    <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @name="communityOwner"
        @title={{i18n "admin.config_areas.about.community_owner"}}
        @description={{i18n "admin.config_areas.about.community_owner_help"}}
        @format="large"
        @type="input"
        as |field|
      >
        <field.Control
          placeholder={{i18n
            "admin.config_areas.about.community_owner_placeholder"
          }}
        />
      </form.Field>

      {{#if @isDefaultLocale}}
        <form.Field
          @name="contactEmail"
          @title={{i18n "admin.config_areas.about.contact_email"}}
          @description={{i18n "admin.config_areas.about.contact_email_help"}}
          @type="input-email"
          @format="large"
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "admin.config_areas.about.contact_email_placeholder"
            }}
          />
        </form.Field>

        <form.Field
          @name="contactURL"
          @title={{i18n "admin.config_areas.about.contact_url"}}
          @description={{i18n "admin.config_areas.about.contact_url_help"}}
          @type="input-url"
          @format="large"
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "admin.config_areas.about.contact_url_placeholder"
            }}
          />
        </form.Field>

        <form.Field
          @name="contactUsername"
          @title={{i18n "admin.config_areas.about.site_contact_name"}}
          @description={{i18n
            "admin.config_areas.about.site_contact_name_help"
          }}
          @onSet={{this.setContactUsername}}
          @format="large"
          @type="custom"
          as |field|
        >
          <field.Control>
            <UserChooser
              @value={{field.value}}
              @options={{hash maximum=1}}
              @onChange={{field.set}}
            />
          </field.Control>
        </form.Field>

        <form.Field
          @name="contactGroupName"
          @title={{i18n "admin.config_areas.about.site_contact_group"}}
          @description={{i18n
            "admin.config_areas.about.site_contact_group_help"
          }}
          @onSet={{this.setContactGroup}}
          @format="large"
          @type="custom"
          as |field|
        >
          <field.Control>
            <GroupChooser
              @content={{this.site.groups}}
              @value={{this.contactGroupId}}
              @options={{hash maximum=1}}
              @onChange={{field.set}}
            />
          </field.Control>
        </form.Field>
      {{/if}}

      <form.Submit
        @label="admin.config_areas.about.update"
        @disabled={{@globalSavingStatus}}
      />
    </Form>
  </template>
}
