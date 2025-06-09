import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { classNameBindings, tagName } from "@ember-decorators/component";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import CategoryTitleLink from "discourse/components/category-title-link";
import PluginOutlet from "discourse/components/plugin-outlet";
import borderColor from "discourse/helpers/border-color";
import categoryColorVariable from "discourse/helpers/category-color-variable";
import categoryLink, {
  categoryBadgeHTML,
} from "discourse/helpers/category-link";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseComputed from "discourse/lib/decorators";

@tagName("section")
@classNameBindings(
  ":category-boxes",
  "anyLogos:with-logos:no-logos",
  "hasSubcategories:with-subcategories"
)
export default class CategoriesBoxes extends Component {
  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any((c) => !isEmpty(c.get("uploaded_logo.url")));
  }

  @discourseComputed("categories.[].subcategories")
  hasSubcategories() {
    return this.categories.any((c) => !isEmpty(c.get("subcategories")));
  }

  categoryName(category) {
    return htmlSafe(
      categoryBadgeHTML(category, {
        allowUncategorized: true,
        link: false,
      })
    );
  }

  <template>
    <PluginOutlet
      @name="categories-boxes-wrapper"
      @outletArgs={{lazyHash categories=this.categories}}
    >
      {{#each this.categories as |c|}}
        <PluginOutlet
          @name="category-box-before-each-box"
          @outletArgs={{lazyHash category=c}}
        />

        <div
          style={{categoryColorVariable c.color}}
          data-category-id={{c.id}}
          data-notification-level={{c.notificationLevelString}}
          data-url={{c.url}}
          class="category category-box category-box-{{c.slug}}
            {{if c.isMuted 'muted'}}"
        >
          <div class="category-box-inner">
            {{#unless c.isMuted}}
              <div class="category-logo">
                {{#if c.uploaded_logo.url}}
                  <CategoryLogo @category={{c}} />
                {{/if}}
              </div>
            {{/unless}}

            <div class="category-details">
              <div class="category-box-heading">
                <a class="parent-box-link" href={{c.url}}>
                  <h3>
                    <CategoryTitleBefore @category={{c}} />
                    {{this.categoryName c}}
                  </h3>
                </a>
              </div>

              {{#unless c.isMuted}}
                <div class="description">
                  {{htmlSafe c.description_excerpt}}
                </div>

                {{#if c.isGrandParent}}
                  {{#each c.subcategories as |subcategory|}}
                    <div
                      data-category-id={{subcategory.id}}
                      data-notification-level={{subcategory.notificationLevelString}}
                      style={{borderColor subcategory.color}}
                      class="subcategory with-subcategories
                        {{if
                          subcategory.uploaded_logo.url
                          'has-logo'
                          'no-logo'
                        }}"
                    >
                      <div class="subcategory-box-inner">
                        <CategoryTitleLink
                          @tagName="h4"
                          @category={{subcategory}}
                        />
                        {{#if subcategory.subcategories}}
                          <div class="subcategories">
                            {{#each
                              subcategory.subcategories
                              as |subsubcategory|
                            }}
                              {{#unless subsubcategory.isMuted}}
                                <span class="subcategory">
                                  <CategoryTitleBefore
                                    @category={{subsubcategory}}
                                  />
                                  {{categoryLink
                                    subsubcategory
                                    hideParent="true"
                                  }}
                                </span>
                              {{/unless}}
                            {{/each}}
                          </div>
                        {{/if}}
                      </div>
                    </div>
                  {{/each}}
                {{else if c.subcategories}}
                  <div class="subcategories">
                    {{#each c.subcategories as |sc|}}
                      <a class="subcategory" href={{sc.url}}>
                        <span class="subcategory-image-placeholder">
                          {{#if sc.uploaded_logo.url}}
                            <CategoryLogo @category={{sc}} />
                          {{/if}}
                        </span>

                        {{categoryLink sc hideParent="true"}}
                      </a>
                    {{/each}}
                  </div>
                {{/if}}
              {{/unless}}
            </div>

            <PluginOutlet
              @name="category-box-below-each-category"
              @outletArgs={{lazyHash category=c}}
            />
          </div>
        </div>

        <PluginOutlet
          @name="category-box-after-each-box"
          @outletArgs={{lazyHash category=c}}
        />
      {{/each}}
    </PluginOutlet>

    <PluginOutlet
      @name="category-boxes-after-boxes"
      @outletArgs={{lazyHash category=this.c}}
    />
  </template>
}
