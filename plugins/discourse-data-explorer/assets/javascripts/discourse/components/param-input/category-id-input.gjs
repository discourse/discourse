import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

export default class CategoryIdInput extends Component {
  @service siteSettings;

  // CategoryChooser will try to modify the value of value,
  // triggering a setting-on-hash error. So we have to do the dirty work.
  get data() {
    return {
      value: this.args.field.value,
    };
  }

  <template>
    <@Control id={{@field.id}}>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-chooser"
          name={{@info.identifier}}
          @describedBy={{@field.describedBy}}
          @disabled={{@field.disabled}}
          @emit="ids"
          @invalid={{if @field.error true false}}
          @noneRow={{true}}
          @onChange={{@field.set}}
          @permission="create"
          @texts={{hash
            ariaLabel=@field.title
            noneLabel=(i18n "category.none")
            placeholder=(i18n "category.none")
          }}
          @value={{this.data.value}}
        />
      {{else}}
        <CategoryChooser
          name={{@info.identifier}}
          @onChange={{@field.set}}
          @options={{hash
            allowUncategorized=null
            autoInsertNoneItem=true
            none=true
          }}
          @value={{this.data.value}}
        />
      {{/if}}
    </@Control>
  </template>
}
