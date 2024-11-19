import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import UserChooser from "select-kit/components/user-chooser";

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
      communityOwner: this.args.contactInformation.communityOwner.value,
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
    set(
      "contactGroupName",
      this.site.groups.find((group) => group.id === groupIds[0])?.name
    );
  }

  @action
  async save(data) {
    try {
      this.args.setGlobalSavingStatus(true);
      await ajax("/admin/config/about.json", {
        type: "PUT",
        data: {
          contact_information: {
            community_owner: data.communityOwner,
            contact_email: data.contactEmail,
            contact_url: data.contactURL,
            contact_username: data.contactUsername,
            contact_group_name: data.contactGroupName,
          },
        },
      });
      this.toasts.success({
        duration: 3000,
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

  <template>
    <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @name="communityOwner"
        @title={{i18n "admin.config_areas.about.community_owner"}}
        @description={{i18n "admin.config_areas.about.community_owner_help"}}
        @format="large"
        as |field|
      >
        <field.Input
          placeholder={{i18n
            "admin.config_areas.about.community_owner_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @name="contactEmail"
        @title={{i18n "admin.config_areas.about.contact_email"}}
        @description={{i18n "admin.config_areas.about.contact_email_help"}}
        @type="email"
        @format="large"
        as |field|
      >
        <field.Input
          placeholder={{i18n
            "admin.config_areas.about.contact_email_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @name="contactURL"
        @title={{i18n "admin.config_areas.about.contact_url"}}
        @description={{i18n "admin.config_areas.about.contact_url_help"}}
        @type="url"
        @format="large"
        as |field|
      >
        <field.Input
          placeholder={{i18n
            "admin.config_areas.about.contact_url_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @name="contactUsername"
        @title={{i18n "admin.config_areas.about.site_contact_name"}}
        @description={{i18n "admin.config_areas.about.site_contact_name_help"}}
        @onSet={{this.setContactUsername}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <UserChooser
            @value={{field.value}}
            @options={{hash maximum=1}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="contactGroupName"
        @title={{i18n "admin.config_areas.about.site_contact_group"}}
        @description={{i18n "admin.config_areas.about.site_contact_group_help"}}
        @onSet={{this.setContactGroup}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{this.contactGroupId}}
            @options={{hash maximum=1}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Submit
        @label="admin.config_areas.about.update"
        @disabled={{@globalSavingStatus}}
      />
    </Form>
  </template>
}
