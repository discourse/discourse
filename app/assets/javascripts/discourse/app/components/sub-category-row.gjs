import CategoryListItem from "discourse/components/category-list-item";
import CategoryTitleLink from "discourse/components/category-title-link";
import SubCategoryItem from "discourse/components/sub-category-item";
import borderColor from "discourse/helpers/border-color";
import dirSpan from "discourse/helpers/dir-span";

export default class SubCategoryRow extends CategoryListItem {
  <template>
    {{#unless this.isHidden}}
      {{#if this.site.mobileView}}
        <tr
          data-category-id={{this.category.id}}
          style={{borderColor this.category.color}}
          class="subcategory-list-item category {{if this.isMuted 'muted'}}"
        >
          <td>
            <CategoryTitleLink @tagName="h4" @category={{this.category}} />
            <div class="subcategories-list">
              {{#if this.category.subcategories}}
                <div class="subcategories">
                  {{#each this.category.subcategories as |subcategory|}}
                    <SubCategoryItem
                      @category={{subcategory}}
                      @listType={{this.listType}}
                    />
                  {{/each}}
                </div>
              {{/if}}
            </div>
          </td>
        </tr>
      {{else}}
        <tr
          data-category-id={{this.category.id}}
          data-notification-level={{this.category.notificationLevelString}}
          class="{{if
              this.category.description_excerpt
              'has-description'
              'no-description'
            }}
            {{if this.category.uploaded_logo.url 'has-logo' 'no-logo'}}"
        >
          <td
            class="category {{if this.isMuted 'muted'}}"
            style={{borderColor this.category.color}}
          >
            <CategoryTitleLink @tagName="h4" @category={{this.category}} />
            {{#if this.category.description_excerpt}}
              <div class="category-description subcategory-description">
                {{dirSpan this.category.description_excerpt htmlSafe="true"}}
              </div>
            {{/if}}
            {{#if this.category.subcategories}}
              <div class="subcategories">
                {{#each this.category.subcategories as |subsubcategory|}}
                  <SubCategoryItem
                    @category={{subsubcategory}}
                    @hideUnread="true"
                    @listType={{this.listType}}
                  />
                {{/each}}
              </div>
            {{/if}}
          </td>
        </tr>
      {{/if}}
    {{/unless}}
  </template>
}
