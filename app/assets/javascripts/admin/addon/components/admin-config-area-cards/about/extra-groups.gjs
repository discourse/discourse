import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";

export default class AdminConfigAreasAboutExtraGroups extends Component {
  @service site;
  @service toasts;

  @cached
  get data() {
    return {
      aboutPageExtraGroups:
        this.args.extraGroups.aboutPageExtraGroups.value
          .split("|")
          .map(Number) || [],
      aboutPageExtraGroupsInitialMembers:
        this.args.extraGroups.aboutPageExtraGroupsInitialMembers.value,
      aboutPageExtraGroupsOrder:
        this.args.extraGroups.aboutPageExtraGroupsOrder.value,
      aboutPageExtraGroupsShowDescription:
        this.args.extraGroups.aboutPageExtraGroupsShowDescription.value ===
        "true",
    };
  }

  @action
  async save(data) {
    this.args.setGlobalSavingStatus(true);
    try {
      await ajax("/admin/config/about.json", {
        type: "PUT",
        data: {
          extra_groups: {
            groups: data.aboutPageExtraGroups.join("|"),
            initial_members: data.aboutPageExtraGroupsInitialMembers,
            order: data.aboutPageExtraGroupsOrder,
            show_description: data.aboutPageExtraGroupsShowDescription,
          },
        },
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin.config_areas.about.toasts.extra_groups_saved"),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.args.setGlobalSavingStatus(false);
    }
  }

  get orderings() {
    return this.args.extraGroups.aboutPageExtraGroupsOrder.choices;
  }

  <template>
    <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @name="aboutPageExtraGroups"
        @title={{i18n "admin.config_areas.about.extra_groups.groups"}}
        @format="large"
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @content={{this.site.groups}}
            @value={{field.value}}
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="aboutPageExtraGroupsInitialMembers"
        @title={{i18n "admin.config_areas.about.extra_groups.initial_members"}}
        @description={{i18n
          "admin.config_areas.about.extra_groups.initial_members_description"
        }}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Input @type="number" />
      </form.Field>

      <form.Field
        @name="aboutPageExtraGroupsOrder"
        @title={{i18n "admin.config_areas.about.extra_groups.order"}}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Select as |select|>
          {{#each this.orderings as |ordering|}}
            <select.Option @value={{ordering}}>
              {{ordering}}
            </select.Option>
          {{/each}}
        </field.Select>
      </form.Field>

      <form.Field
        @name="aboutPageExtraGroupsShowDescription"
        @title={{i18n "admin.config_areas.about.extra_groups.show_description"}}
        @validation="required"
        @format="large"
        as |field|
      >
        <field.Checkbox />
      </form.Field>

      <form.Submit
        @label="admin.config_areas.about.update"
        @disabled={{@globalSavingStatus}}
      />
    </Form>
  </template>
}
