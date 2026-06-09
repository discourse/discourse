import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  AUTO_GROUPS,
  CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS,
} from "discourse/lib/constants";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";

export default class AssignSettingsUpsert extends Component {
  @service site;
  @service siteSettings;

  get enableUnassignedFilter() {
    const value =
      this.args.outletArgs.transientData?.custom_fields
        ?.enable_unassigned_filter;
    return value?.toString() === "true";
  }

  get globalAssignAllowedGroupIds() {
    return this.groupIdsFromValue(this.siteSettings.assign_allowed_on_groups);
  }

  get additionalAssignAllowedGroupIds() {
    const value =
      this.args.outletArgs.transientData?.custom_fields?.[
        CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS
      ];

    return [
      ...new Set([
        ...this.globalAssignAllowedGroupIds,
        ...this.groupIdsFromValue(value),
      ]),
    ];
  }

  get assignAllowedMandatoryGroupIds() {
    return this.globalAssignAllowedGroupIds.join("|");
  }

  groupIdsFromValue(value) {
    return (value || "")
      .split("|")
      .filter(Boolean)
      .filter((groupId) => parseInt(groupId, 10) !== AUTO_GROUPS.everyone.id);
  }

  get assignableGroups() {
    return (this.site.groups || [])
      .filter((group) => group.id !== AUTO_GROUPS.everyone.id)
      .map((group) => ({ ...group, id: group.id.toString() }));
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
        .filter((groupId) => parseInt(groupId, 10) !== AUTO_GROUPS.everyone.id)
        .filter(
          (groupId) => !this.globalAssignAllowedGroupIds.includes(groupId)
        )
        .join("|")
    );
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "discourse_assign.assign.title"}}>
        <form.Object @name="custom_fields" as |customFields|>
          <customFields.Field
            @name={{CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS}}
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
                @mandatoryValues={{this.assignAllowedMandatoryGroupIds}}
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
