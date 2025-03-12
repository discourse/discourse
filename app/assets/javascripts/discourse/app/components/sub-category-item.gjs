import CategoryListItem from "discourse/components/category-list-item";

export default class SubCategoryItem extends CategoryListItem {}

{{#unless this.isMuted}}
  {{#if this.site.mobileView}}
    {{category-link this.category}}
  {{else}}
    <span class="subcategory">
      <CategoryTitleBefore @category={{this.category}} />
      {{category-link this.category hideParent="true"}}
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