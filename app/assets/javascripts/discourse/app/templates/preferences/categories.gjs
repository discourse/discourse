import RouteTemplate from "ember-route-template";
import SaveControls from "discourse/components/save-controls";
import Categories from "discourse/components/user-preferences/categories";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <Categories
      @canSee={{@controller.canSee}}
      @model={{@controller.model}}
      @selectedCategories={{@controller.selectedCategories}}
      @hideMutedTags={{@controller.hideMutedTags}}
      @save={{@controller.save}}
      @siteSettings={{@controller.siteSettings}}
    />

    {{#if @controller.canSave}}
      <SaveControls
        @model={{@controller.model}}
        @action={{@controller.save}}
        @saved={{@controller.saved}}
      />
    {{else}}
      {{i18n "user.no_category_access"}}
    {{/if}}
  </template>
);
