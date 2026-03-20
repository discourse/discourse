/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import CategoriesBoxesTopic from "discourse/components/categories-boxes-topic";
import CategoryLogo from "discourse/components/category-logo";
import CategoryTitleBefore from "discourse/components/category-title-before";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryColorVariable from "discourse/helpers/category-color-variable";
import lazyHash from "discourse/helpers/lazy-hash";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

@tagName("")
export default class CategoriesBoxesWithTopics extends Component {
  get anyLogos() {
    return this.categories.some((c) => {
      return !isEmpty(c.get("uploaded_logo.url"));
    });
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
        "category-boxes-with-topics"
        (if this.anyLogos "with-logos" "no-logos")
      }}
      ...attributes
    >
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
    </section>
  </template>
}
