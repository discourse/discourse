import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

export default class ChangeCategory extends Component {
  @service siteSettings;

  categoryId = 0;

  @action
  async changeCategory() {
    await this.args.forEachPerformed(
      {
        type: "change_category",
        category_id: this.categoryId,
      },
      (t) => t.set("category_id", this.categoryId)
    );
  }

  <template>
    <p>{{i18n "topics.bulk.choose_new_category"}}</p>

    <p>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-chooser"
          @emit="ids"
          @onChange={{fn (mut this.categoryId)}}
          @permission="create"
          @value={{this.categoryId}}
        />
      {{else}}
        <CategoryChooser
          @onChange={{fn (mut this.categoryId)}}
          @value={{this.categoryId}}
        />
      {{/if}}
    </p>

    <DConditionalLoadingSpinner @condition={{@loading}}>
      <DButton
        @action={{this.changeCategory}}
        @label="topics.bulk.change_category"
      />
    </DConditionalLoadingSpinner>
  </template>
}
