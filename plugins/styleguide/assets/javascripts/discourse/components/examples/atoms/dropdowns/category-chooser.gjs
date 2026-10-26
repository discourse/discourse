import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";

export default class CategoryChooserExample extends Component {
  @service siteSettings;

  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectCategory
        class="category-chooser"
        @emit="ids"
        @multiple={{false}}
        @onChange={{this.onChange}}
        @permission="create"
        @value={{this.value}}
      />
    {{else}}
      <CategoryChooser @onChange={{this.onChange}} @value={{this.value}} />
    {{/if}}
  </template>
}
