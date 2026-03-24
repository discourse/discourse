/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import ParentCategoryRow from "discourse/components/parent-category-row";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

@tagName("")
export default class CategoriesOnly extends Component {
  showMuted = false;

  @computed("showMutedCategories", "filteredCategories.length")
  get mutedToggleIcon() {
    if (this.filteredCategories?.length === 0) {
      return;
    }

    if (this.showMutedCategories) {
      return "minus";
    }

    return "plus";
  }

  @computed("showMuted", "filteredCategories.length")
  get showMutedCategories() {
    return this.showMuted || this.filteredCategories?.length === 0;
  }

  @computed("categories", "categories.length")
  get filteredCategories() {
    if (!this.categories || this.categories?.length === 0) {
      return [];
    }

    return this.categories.filter((cat) => !cat.isHidden);
  }

  @computed("categories", "categories.length")
  get mutedCategories() {
    if (!this.categories || this.categories?.length === 0) {
      return [];
    }

    // hide in single category pages
    if (this.categories[0].parent_category_id) {
      return [];
    }

    return this.categories.filter((category) => category.hasMuted);
  }

  @action
  toggleShowMuted(event) {
    event?.preventDefault();
    this.toggleProperty("showMuted");
  }

  <template>
    <PluginOutlet
      @name="categories-only-wrapper"
      @outletArgs={{lazyHash categories=this.categories}}
    >
      {{#if this.categories}}
        {{#if this.filteredCategories}}
          {{#if this.site.mobileView}}
            <div class="category-list {{if this.showTopics 'with-topics'}}">
              <PluginOutlet
                @name="mobile-categories"
                @outletArgs={{lazyHash categories=this.filteredCategories}}
              >
                {{#each this.filteredCategories as |c|}}
                  <ParentCategoryRow
                    @category={{c}}
                    @showTopics={{this.showTopics}}
                  />
                {{/each}}
              </PluginOutlet>
            </div>
          {{else}}
            <table class="category-list {{if this.showTopics 'with-topics'}}">
              <thead>
                <tr>
                  <th class="category"><span
                      role="heading"
                      aria-level="2"
                      id="categories-only-category"
                    >{{i18n "categories.category"}}</span></th>
                  <th class="topics">{{i18n "categories.topics"}}</th>
                  {{#if this.showTopics}}
                    <th class="latest">{{i18n "categories.latest"}}</th>
                  {{/if}}
                </tr>
              </thead>
              <tbody aria-labelledby="categories-only-category">
                {{#each this.categories as |category|}}
                  <ParentCategoryRow
                    @category={{category}}
                    @showTopics={{this.showTopics}}
                  />
                {{/each}}
              </tbody>
            </table>
          {{/if}}
        {{/if}}

        {{#if this.mutedCategories}}
          <div class="muted-categories">
            <a
              href
              class="muted-categories-link"
              {{on "click" this.toggleShowMuted}}
            >
              <h3 class="muted-categories-heading">{{i18n
                  "categories.muted"
                }}</h3>
              {{#if this.mutedToggleIcon}}
                {{icon this.mutedToggleIcon}}
              {{/if}}
            </a>
            {{#if this.site.mobileView}}
              <div
                class="category-list
                  {{if this.showTopics 'with-topics'}}
                  {{unless this.showMutedCategories 'hidden'}}"
              >
                {{#each this.mutedCategories as |c|}}
                  <ParentCategoryRow
                    @category={{c}}
                    @showTopics={{this.showTopics}}
                    @listType="muted"
                  />
                {{/each}}
              </div>
            {{else}}
              <table
                class="category-list
                  {{if this.showTopics 'with-topics'}}
                  {{unless this.showMutedCategories 'hidden'}}"
              >
                <thead>
                  <tr>
                    <th class="category"><span
                        role="heading"
                        aria-level="2"
                        id="categories-only-category-muted"
                      >{{i18n "categories.category"}}</span></th>
                    <th class="topics">{{i18n "categories.topics"}}</th>
                    {{#if this.showTopics}}
                      <th class="latest">{{i18n "categories.latest"}}</th>
                    {{/if}}
                  </tr>
                </thead>
                <tbody aria-labelledby="categories-only-category-muted">
                  {{#each this.categories as |category|}}
                    <ParentCategoryRow
                      @category={{category}}
                      @showTopics={{this.showTopics}}
                      @listType="muted"
                    />
                  {{/each}}
                </tbody>
              </table>
            {{/if}}
          </div>
        {{/if}}
      {{/if}}
    </PluginOutlet>

    <PluginOutlet
      @name="below-categories-only"
      @connectorTagName="div"
      @outletArgs={{lazyHash
        categories=this.categories
        showTopics=this.showTopics
      }}
    />
  </template>
}
