import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

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

  get orderings() {
    return this.args.extraGroups.aboutPageExtraGroupsOrder.choices;
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

  <template>
    <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @format="large"
        @name="aboutPageExtraGroups"
        @title={{i18n "admin.config_areas.about.extra_groups.groups"}}
        @type="custom"
        as |field|
      >
        <field.Control>
          <GroupChooser
            @content={{this.site.groups}}
            @onChange={{field.set}}
            @value={{field.value}}
          />
        </field.Control>
      </form.Field>

      <form.Field
        @description={{i18n
          "admin.config_areas.about.extra_groups.initial_members_description"
        }}
        @format="large"
        @name="aboutPageExtraGroupsInitialMembers"
        @title={{i18n "admin.config_areas.about.extra_groups.initial_members"}}
        @type="input-number"
        @validation="required"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @format="large"
        @name="aboutPageExtraGroupsOrder"
        @title={{i18n "admin.config_areas.about.extra_groups.order"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control as |select|>
          {{#each this.orderings as |ordering|}}
            <select.Option @value={{ordering}}>
              {{ordering}}
            </select.Option>
          {{/each}}
        </field.Control>
      </form.Field>

      <form.Field
        @format="large"
        @name="aboutPageExtraGroupsShowDescription"
        @title={{i18n "admin.config_areas.about.extra_groups.show_description"}}
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Submit
        @disabled={{@globalSavingStatus}}
        @label="admin.config_areas.about.update"
      />
    </Form>
  </template>
}
