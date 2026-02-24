import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class AssignSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  get enableUnassignedFilter() {
    const value =
      this.args.outletArgs.transientData?.custom_fields
        ?.enable_unassigned_filter;
    return value === "true" || value === true;
  }

  @action
  onToggleUnassignedFilter(value) {
    this.args.outletArgs.form.set(
      "custom_fields.enable_unassigned_filter",
      value ? "true" : "false"
    );
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "discourse_assign.assign.title"}}>
        <div
          class="form-kit__container form-kit__field form-kit__field-checkbox"
        >
          <div class="form-kit__container-content">
            <label class="form-kit__control-checkbox-label">
              <input
                class="form-kit__control-checkbox"
                type="checkbox"
                checked={{this.enableUnassignedFilter}}
                {{on
                  "change"
                  (withEventValue
                    this.onToggleUnassignedFilter "target.checked"
                  )
                }}
              />
              <span class="form-kit__control-checkbox-content">
                <span class="form-kit__control-checkbox-title">
                  <span>{{i18n "discourse_assign.add_unassigned_filter"}}</span>
                </span>
              </span>
            </label>
          </div>
        </div>
      </form.Section>
    {{/let}}
  </template>
}
