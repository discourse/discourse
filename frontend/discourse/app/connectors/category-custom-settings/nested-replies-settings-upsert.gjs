import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class NestedRepliesSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  get enabled() {
    const value =
      this.args.outletArgs.transientData?.category_setting
        ?.nested_replies_default;
    return !!value;
  }

  @action
  async onToggle(_, { set, name }) {
    await set(name, !this.enabled);
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "nested_replies.nested_view"}}>
        <form.Object @name="category_setting" as |categorySetting|>
          <categorySetting.Field
            @name="nested_replies_default"
            @title={{i18n
              "nested_replies.category_settings.default_nested_view"
            }}
            @onSet={{this.onToggle}}
            as |field|
          >
            <field.Checkbox checked={{this.enabled}} />
          </categorySetting.Field>
        </form.Object>
      </form.Section>
    {{/let}}
  </template>
}
