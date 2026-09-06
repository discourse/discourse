/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import CategoryTitleLink from "discourse/components/category-title-link";
import PluginOutlet from "discourse/components/plugin-outlet";
import borderColor from "discourse/helpers/border-color";
import categoryColorVariable from "discourse/helpers/category-color-variable";
import categoryListSubcategories, {
  hasGrandchildren,
} from "discourse/helpers/category-list-subcategories";
import lazyHash from "discourse/helpers/lazy-hash";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import dCategoryLink, {
  categoryBadgeHTML,
} from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDirSpan from "discourse/ui-kit/helpers/d-dir-span";

@tagName("")
export default class CategoriesBoxes extends Component {
  @service discovery;

  get anyLogos() {
    return this.categories.some((c) => !isEmpty(c.get("uploaded_logo.url")));
  }

  get hasSubcategories() {
    return this.categories.some(
      (c) => !isEmpty(categoryListSubcategories(c, { page: this.page }))
    );
  }

  get page() {
    return this.categoryListPage ?? this.discovery.categoryListPage;
  }

  categoryName(category) {
    return trustHTML(
      categoryBadgeHTML(category, {
        allowUncategorized: true,
        link: false,
      })
    );
  }

  <template>
    <section
      class={{dConcatClass
        "category-boxes"
        (if this.anyLogos "with-logos" "no-logos")
        (if this.hasSubcategories "with-subcategories")
      }}
      ...attributes
    >
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
                    <DDecoratedHtml
                      @html={{dDirSpan c.description_excerpt htmlSafe="true"}}
                    />
                  </div>

                  {{#let
                    (categoryListSubcategories c page=this.page)
                    as |subcategories|
                  }}
                    {{#if (hasGrandchildren subcategories page=this.page)}}
                      {{#each subcategories as |subcategory|}}
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
                            {{#let
                              (categoryListSubcategories
                                subcategory page=this.page
                              )
                              as |grandchildren|
                            }}
                              {{#if grandchildren}}
                                <div class="subcategories">
                                  {{#each grandchildren as |subsubcategory|}}
                                    {{#unless subsubcategory.isMuted}}
                                      <span class="subcategory">
                                        <CategoryTitleBefore
                                          @category={{subsubcategory}}
                                        />
                                        {{dCategoryLink
                                          subsubcategory
                                          hideParent="true"
                                        }}
                                      </span>
                                    {{/unless}}
                                  {{/each}}
                                </div>
                              {{/if}}
                            {{/let}}
                          </div>
                        </div>
                      {{/each}}
                    {{else if subcategories}}
                      <div class="subcategories">
                        {{#each subcategories as |sc|}}
                          <a class="subcategory" href={{sc.url}}>
                            {{#if sc.uploaded_logo.url}}
                              <span class="subcategory-image-placeholder">
                                <CategoryLogo @category={{sc}} />
                              </span>
                            {{/if}}
                            {{dCategoryLink sc hideParent="true"}}
                          </a>
                        {{/each}}
                      </div>
                    {{/if}}
                  {{/let}}
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
    </section>
  </template>
}
