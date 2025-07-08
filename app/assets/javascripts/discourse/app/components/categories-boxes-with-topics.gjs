import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { classNameBindings, tagName } from "@ember-decorators/component";
import CategoriesBoxesTopic from "discourse/components/categories-boxes-topic";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryColorVariable from "discourse/helpers/category-color-variable";
import { categoryBadgeHTML } from "discourse/helpers/category-link";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseComputed from "discourse/lib/decorators";

@tagName("section")
@classNameBindings(
  ":category-boxes-with-topics",
  "anyLogos:with-logos:no-logos"
)
export default class CategoriesBoxesWithTopics extends Component {
  @discourseComputed("categories.[].uploaded_logo.url")
  anyLogos() {
    return this.categories.any((c) => {
      return !isEmpty(c.get("uploaded_logo.url"));
    });
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
    {{#each this.categories as |c|}}
      <div
        data-notification-level={{c.notificationLevelString}}
        style={{categoryColorVariable c.color}}
        class="category category-box category-box-{{c.slug}}
          {{if c.isMuted 'muted'}}"
      >
        <div class="category-box-inner">
          <div class="category-box-heading">
            <a class="parent-box-link" href={{c.url}}>
              {{#unless c.isMuted}}
                {{#if c.uploaded_logo.url}}
                  <CategoryLogo @category={{c}} />
                {{/if}}
              {{/unless}}

              <h3>
                <CategoryTitleBefore @category={{c}} />
                {{this.categoryName c}}
              </h3>
            </a>
          </div>

          {{#unless c.isMuted}}
            <div class="featured-topics">
              {{#if c.topics}}
                <ul>
                  {{#each c.topics as |topic|}}
                    <CategoriesBoxesTopic @topic={{topic}} />
                  {{/each}}
                </ul>
              {{/if}}
            </div>
          {{/unless}}

          <PluginOutlet
            @name="category-box-below-each-category"
            @outletArgs={{lazyHash category=c}}
          />
        </div>
      </div>
    {{/each}}
  </template>
}
