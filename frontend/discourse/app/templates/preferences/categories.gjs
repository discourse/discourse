import Categories from "discourse/components/user-preferences/categories";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import { i18n } from "discourse-i18n";

export default <template>
  <Categories
    @canSee={{@controller.canSee}}
    @model={{@controller.model}}
    @selectedCategories={{@controller.selectedCategories}}
    @hideMutedTags={{@controller.hideMutedTags}}
    @save={{@controller.save}}
    @siteSettings={{@controller.siteSettings}}
  />

  {{#if @controller.canSave}}
    <DSaveControls
      @model={{@controller.model}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
    />
  {{else}}
    {{i18n "user.no_category_access"}}
  {{/if}}
</template>
