import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

const ADDITIONAL_ASSIGN_ALLOWED_GROUPS = "additional_assign_allowed_on_groups";
const EVERYONE_GROUP_ID = 0;

export default class AssignSettingsUpsert extends Component {
  @service site;

  get enableUnassignedFilter() {
    const value =
      this.args.outletArgs.transientData?.custom_fields
        ?.enable_unassigned_filter;
    return value?.toString() === "true";
  }

  get additionalAssignAllowedGroupIds() {
    const value =
      this.args.outletArgs.transientData?.custom_fields?.[
        ADDITIONAL_ASSIGN_ALLOWED_GROUPS
      ];

    return (value || "")
      .split("|")
      .filter(Boolean)
      .map((groupId) => parseInt(groupId, 10))
      .filter((groupId) => groupId !== EVERYONE_GROUP_ID);
  }

  get assignableGroups() {
    return (this.site.groups || []).filter(
      (group) => group.id !== EVERYONE_GROUP_ID
    );
  }

  @action
  async onToggleUnassignedFilter(_, { set, name }) {
    await set(name, this.enableUnassignedFilter ? "false" : "true");
  }

  @action
  async onChangeAssignAllowedGroups(groupIds, { set, name }) {
    await set(
      name,
      (groupIds || [])
        .filter((groupId) => groupId !== EVERYONE_GROUP_ID)
        .join("|")
    );
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "discourse_assign.assign.title"}}>
        <form.Object @name="custom_fields" as |customFields|>
          <customFields.Field
            @name={{ADDITIONAL_ASSIGN_ALLOWED_GROUPS}}
            @title={{i18n "discourse_assign.additional_assign_allowed_groups"}}
            @description={{i18n
              "discourse_assign.additional_assign_allowed_groups_description"
            }}
            @onSet={{this.onChangeAssignAllowedGroups}}
            @type="custom"
            @format="full"
            as |field|
          >
            <field.Control>
              <GroupChooser
                @content={{this.assignableGroups}}
                @value={{this.additionalAssignAllowedGroupIds}}
                @onChange={{field.set}}
              />
            </field.Control>
          </customFields.Field>

          <customFields.Field
            @name="enable_unassigned_filter"
            @title={{i18n "discourse_assign.add_unassigned_filter"}}
            @onSet={{this.onToggleUnassignedFilter}}
            @type="checkbox"
            @format="full"
            as |field|
          >
            <field.Control checked={{this.enableUnassignedFilter}} />
          </customFields.Field>
        </form.Object>
      </form.Section>
    {{/let}}
  </template>
}
