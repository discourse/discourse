import CategoryListItem from "discourse/components/category-list-item";
import CategoryTitleBefore from "discourse/components/category-title-before";
import CategoryUnread from "discourse/components/category-unread";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryLink from "discourse/helpers/category-link";
import lazyHash from "discourse/helpers/lazy-hash";

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
