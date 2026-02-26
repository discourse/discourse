import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class AssignSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  get enableUnassignedFilter() {
    const value =
      this.args.outletArgs.transientData?.custom_fields
        ?.enable_unassigned_filter;
    return value?.toString() === "true";
  }

  @action
  async onToggleUnassignedFilter(_, { set, name }) {
    await set(name, !this.enableUnassignedFilter);
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "discourse_assign.assign.title"}}>
        <form.Object @name="custom_fields" as |customFields|>
          <customFields.Field
            @name="enable_unassigned_filter"
            @title={{i18n "discourse_assign.add_unassigned_filter"}}
            @onSet={{this.onToggleUnassignedFilter}}
            as |field|
          >
            <field.Checkbox checked={{this.enableUnassignedFilter}} />
          </customFields.Field>
        </form.Object>
      </form.Section>
    {{/let}}
  </template>
}
