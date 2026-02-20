import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { i18n } from "discourse-i18n";

export default class AssignSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  @tracked enableUnassignedFilter;

  constructor() {
    super(...arguments);
    const value =
      this.args.outletArgs.category.custom_fields.enable_unassigned_filter;
    this.enableUnassignedFilter = value === "true" || value === true;
  }

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  @action
  onToggleUnassignedFilter() {
    this.enableUnassignedFilter = !this.enableUnassignedFilter;
    this.customFields.enable_unassigned_filter = this.enableUnassignedFilter
      ? "true"
      : "false";
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "discourse_assign.assign.title"}}>
        <form.Container
          @title={{i18n "discourse_assign.add_unassigned_filter"}}
        >
          <DToggleSwitch
            @state={{this.enableUnassignedFilter}}
            {{on "click" this.onToggleUnassignedFilter}}
          />
        </form.Container>
      </form.Section>
    {{/let}}
  </template>
}
