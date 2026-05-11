import CategoryListItem from "discourse/components/category-list-item";
import CategoryTitleBefore from "discourse/components/category-title-before";
import CategoryUnread from "discourse/components/category-unread";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";

export default class SubCategoryItem extends CategoryListItem {
  <template>
    <PluginOutlet
      @name="sub-category-item"
      @outletArgs={{lazyHash
        category=this.category
        isMuted=this.isMuted
        hideUnread=this.hideUnread
        unreadTopicsCount=this.unreadTopicsCount
        newTopicsCount=this.newTopicsCount
      }}
    >
      {{#unless this.isMuted}}
        {{#if this.site.mobileView}}
          {{dCategoryLink this.category}}
        {{else}}
          <span class="subcategory">
            <CategoryTitleBefore @category={{this.category}} />
            {{dCategoryLink this.category hideParent="true"}}
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
