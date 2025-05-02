import PluginOutlet from "discourse/components/plugin-outlet";
import CategoryListItem from "discourse/components/category-list-item";
import CategoryTitleBefore from "discourse/components/category-title-before";
import CategoryUnread from "discourse/components/category-unread";
import categoryLink from "discourse/helpers/category-link";

export default class SubCategoryItem extends CategoryListItem {
  <template>
    <PluginOutlet
      @name="sub-category-item"
      @outletArgs={{hash subCategoryItem=this}}>
      {{#unless this.isMuted}}
        {{#if this.site.mobileView}}
          {{categoryLink this.category}}
        {{else}}
          <span class="subcategory">
            <CategoryTitleBefore @category={{this.category}} />
            {{categoryLink this.category hideParent="true"}}
            {{#unless this.hideUnread}}
              <CategoryUnread
                @category={{this.category}}
                @unreadTopicsCount={{this.unreadTopicsCount}}
                @newTopicsCount={{this.newTopicsCount}}
              />
            {{/unless}}
          </span>
        {{/if}}
      {{/unless}}
    </PluginOutlet>
  </template>
}
