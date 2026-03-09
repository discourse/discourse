import Component from "@glimmer/component";
import EditCategoryTypeSchemaFields from "discourse/components/edit-category-type-schema-fields";
import { i18n } from "discourse-i18n";

export default class UpsertCategorySupport extends Component {
  get isSupportCategory() {
    return this.args.category.isType("support");
  }

  <template>
    {{#if this.isSupportCategory}}
      <EditCategoryTypeSchemaFields
        @category={{@category}}
        @categoryType="support"
        @form={{@form}}
      />
    {{else}}
      {{i18n "solved.category_type_support.not_support_type"}}
    {{/if}}
  </template>
}
