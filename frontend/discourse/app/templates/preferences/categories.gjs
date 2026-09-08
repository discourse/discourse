import Categories from "discourse/components/user-preferences/categories";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import { i18n } from "discourse-i18n";

export default <template>
  <Categories
    @canSee={{@controller.canSee}}
    @hideMutedTags={{@controller.hideMutedTags}}
    @model={{@controller.model}}
    @save={{@controller.save}}
    @selectedCategories={{@controller.selectedCategories}}
    @siteSettings={{@controller.siteSettings}}
  />

  {{#if @controller.canSave}}
    <DSaveControls
      @action={{@controller.save}}
      @model={{@controller.model}}
      @saved={{@controller.saved}}
    />
  {{else}}
    {{i18n "user.no_category_access"}}
  {{/if}}
</template>
