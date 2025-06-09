import { array, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import { gt } from "truth-helpers";
import CategoryListItem from "discourse/components/category-list-item";
import CategoryTitleLink from "discourse/components/category-title-link";
import CategoryUnread from "discourse/components/category-unread";
import MobileCategoryTopic from "discourse/components/mobile-category-topic";
import PluginOutlet from "discourse/components/plugin-outlet";
import SubCategoryItem from "discourse/components/sub-category-item";
import SubCategoryRow from "discourse/components/sub-category-row";
import FeaturedTopic from "discourse/components/topic-list/featured-topic";
import borderColor from "discourse/helpers/border-color";
import categoryColorVariable from "discourse/helpers/category-color-variable";
import dirSpan from "discourse/helpers/dir-span";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class ParentCategoryRow extends CategoryListItem {
  <template>
    {{#unless this.isHidden}}
      <PluginOutlet
        @name="category-list-above-each-category"
        @outletArgs={{lazyHash category=this.category}}
      />

      {{#if this.site.mobileView}}
        <PluginOutlet
          @name="category-list-before-category-mobile"
          @outletArgs={{lazyHash
            category=this.category
            listType=this.listType
            isMuted=this.isMuted
          }}
        />
        <div
          data-category-id={{this.category.id}}
          data-notification-level={{this.category.notificationLevelString}}
          style={{borderColor this.category.color}}
          class="category-list-item category {{if this.isMuted 'muted'}}"
        >
          <table class="topic-list">
            <tbody>
              <tr>
                <th class="main-link">
                  <CategoryTitleLink @category={{this.category}} />
                </th>
                <PluginOutlet
                  @name="category-list-after-title-mobile-section"
                  @outletArgs={{lazyHash category=this.category}}
                />
              </tr>
              {{#if this.category.description_excerpt}}
                <tr class="category-description">
                  <td colspan="3">
                    {{htmlSafe this.category.description_excerpt}}
                  </td>
                </tr>
              {{/if}}
              {{#unless this.isMuted}}
                {{#if this.showTopics}}
                  {{#each this.category.featuredTopics as |t|}}
                    <MobileCategoryTopic @topic={{t}} />
                  {{/each}}
                {{/if}}
              {{/unless}}
              {{#if this.category.isGrandParent}}
                {{#each this.category.subcategories as |subcategory|}}
                  <SubCategoryRow
                    @category={{subcategory}}
                    @listType={{this.listType}}
                  />
                {{/each}}
              {{else if this.category.subcategories}}
                <tr class="subcategories-list">
                  <td>
                    <div class="subcategories">
                      {{#each this.category.subcategories as |subcategory|}}
                        <SubCategoryItem
                          @category={{subcategory}}
                          @listType={{this.listType}}
                        />
                      {{/each}}
                    </div>
                  </td>
                </tr>
              {{/if}}
            </tbody>
          </table>
          <footer class="clearfix category-topics-count">
            <div class="category-stat">
              <a href={{this.category.url}}>
                {{htmlSafe this.category.statTotal}}
              </a>
            </div>
            {{#unless this.category.pickAll}}
              <div class="category-stat">
                <a href={{this.category.url}}>
                  {{htmlSafe this.category.stat}}
                </a>
              </div>
            {{/unless}}
          </footer>
        </div>
      {{else}}

        <tr
          data-category-id={{this.category.id}}
          data-notification-level={{this.category.notificationLevelString}}
          class="{{if
              this.category.description_excerpt
              'has-description'
              'no-description'
            }}
            {{this.applyValueTransformer
              'parent-category-row-class'
              (array)
              (hash category=this.category)
            }}
            {{if this.category.uploaded_logo.url 'has-logo' 'no-logo'}}"
        >

          <PluginOutlet
            @name="category-list-before-category-section"
            @outletArgs={{lazyHash
              category=this.category
              listType=this.listType
            }}
          />

          <td
            class="category {{if this.isMuted 'muted'}}"
            style={{categoryColorVariable this.category.color}}
          >
            <CategoryTitleLink @category={{this.category}} />
            <PluginOutlet
              @name="below-category-title-link"
              @connectorTagName="div"
              @outletArgs={{lazyHash category=this.category}}
            />

            {{#if this.category.description_excerpt}}
              <div class="category-description">
                {{dirSpan this.category.description_excerpt htmlSafe="true"}}
              </div>
            {{/if}}

            {{#if this.category.isGrandParent}}
              <table class="category-list subcategories-with-subcategories">
                <tbody>
                  {{#each this.category.subcategories as |subcategory|}}
                    <SubCategoryRow
                      @category={{subcategory}}
                      @listType={{this.listType}}
                    />
                  {{/each}}
                  {{#if (gt this.category.unloadedSubcategoryCount 0)}}
                    {{i18n
                      "category_row.subcategory_count"
                      count=this.category.unloadedSubcategoryCount
                    }}
                  {{/if}}
                </tbody>
              </table>
            {{else if this.category.subcategories}}
              <div class="subcategories">
                {{#each this.category.subcategories as |subcategory|}}
                  <SubCategoryItem
                    @category={{subcategory}}
                    @listType={{this.listType}}
                  />
                {{/each}}
                {{#if (gt this.category.unloadedSubcategoryCount 0)}}
                  <div class="subcategories__more-subcategories">
                    <LinkTo
                      @route="discovery.subcategories"
                      @model={{this.slugPath}}
                    >
                      {{i18n
                        "category_row.subcategory_count"
                        count=this.category.unloadedSubcategoryCount
                      }}
                    </LinkTo>
                  </div>
                {{/if}}
              </div>
            {{/if}}
          </td>

          <PluginOutlet
            @name="category-list-before-topics-section"
            @outletArgs={{lazyHash category=this.category}}
          />

          <PluginOutlet
            @name="category-list-topics-wrapper"
            @outletArgs={{lazyHash category=this.category}}
          >
            <td class="topics">
              <div title={{this.category.statTitle}}>{{htmlSafe
                  this.category.stat
                }}</div>
              <CategoryUnread
                @category={{this.category}}
                @tagName="div"
                @unreadTopicsCount={{this.unreadTopicsCount}}
                @newTopicsCount={{this.newTopicsCount}}
                class="unread-new"
              />
            </td>
          </PluginOutlet>

          <PluginOutlet
            @name="category-list-after-topics-section"
            @outletArgs={{lazyHash category=this.category}}
          />

          <PluginOutlet
            @name="category-list-latest-wrapper"
            @outletArgs={{lazyHash
              category=this.category
              showTopics=this.showTopics
            }}
          >
            {{#unless this.isMuted}}
              {{#if this.showTopics}}
                <td class="latest">
                  {{#each this.category.featuredTopics as |t|}}
                    <FeaturedTopic @topic={{t}} />
                  {{/each}}
                </td>
                <PluginOutlet
                  @name="category-list-after-latest-section"
                  @outletArgs={{lazyHash category=this.category}}
                />
              {{/if}}
            {{/unless}}
          </PluginOutlet>
        </tr>
      {{/if}}
    {{/unless}}
  </template>
}
