import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ParentCategoryRow from "discourse/components/parent-category-row";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class CategoriesOnly extends Component {
  @service site;

  @tracked showMuted = false;

  get mutedToggleIcon() {
    if (this.filteredCategories?.length === 0) {
      return;
    }

    if (this.showMutedCategories) {
      return "minus";
    }

    return "plus";
  }

  get showMutedCategories() {
    return this.showMuted || this.filteredCategories?.length === 0;
  }

  @cached
  get filteredCategories() {
    const categories = this.args.categories;
    if (!categories || categories?.length === 0) {
      return [];
    }

    return categories.filter((cat) => !cat.isHidden);
  }

  @cached
  get mutedCategories() {
    const categories = this.args.categories;
    if (!categories || categories?.length === 0) {
      return [];
    }

    // hide in single category pages
    if (categories[0].parent_category_id) {
      return [];
    }

    return categories.filter((category) => category.hasMuted);
  }

  @action
  toggleShowMuted(event) {
    event?.preventDefault();
    this.showMuted = !this.showMuted;
  }

  <template>
    <PluginOutlet
      @name="categories-only-wrapper"
      @outletArgs={{lazyHash categories=@categories}}
    >
      {{#if @categories}}
        {{#if this.filteredCategories}}
          {{#if this.site.mobileView}}
            <div class="category-list {{if @showTopics 'with-topics'}}">
              <PluginOutlet
                @name="mobile-categories"
                @outletArgs={{lazyHash categories=this.filteredCategories}}
              >
                {{#each this.filteredCategories as |c|}}
                  <ParentCategoryRow
                    @category={{c}}
                    @showTopics={{@showTopics}}
                  />
                {{/each}}
              </PluginOutlet>
            </div>
          {{else}}
            <table class="category-list {{if @showTopics 'with-topics'}}">
              <thead class="category-list-header">
                <tr>
                  <th class="category topic-list-data default"><span
                      aria-level="2"
                      id="categories-only-category"
                      role="heading"
                    >{{i18n "categories.category"}}</span></th>
                  <th class="topics topic-list-data num">{{i18n
                      "categories.topics"
                    }}</th>
                  {{#if @showTopics}}
                    <th class="latest">{{i18n "categories.latest"}}</th>
                  {{/if}}
                </tr>
              </thead>
              <tbody aria-labelledby="categories-only-category">
                {{#each @categories as |category|}}
                  <ParentCategoryRow
                    @category={{category}}
                    @showTopics={{@showTopics}}
                  />
                {{/each}}
              </tbody>
            </table>
          {{/if}}
        {{/if}}

        {{#if this.mutedCategories}}
          <div class="muted-categories">
            <a
              class="muted-categories-link"
              href
              {{on "click" this.toggleShowMuted}}
            >
              <h3 class="muted-categories-heading">{{i18n
                  "categories.muted"
                }}</h3>
              {{#if this.mutedToggleIcon}}
                {{dIcon this.mutedToggleIcon}}
              {{/if}}
            </a>
            {{#if this.site.mobileView}}
              <div
                class="category-list
                  {{if @showTopics 'with-topics'}}
                  {{unless this.showMutedCategories 'hidden'}}"
              >
                {{#each this.mutedCategories as |c|}}
                  <ParentCategoryRow
                    @category={{c}}
                    @listType="muted"
                    @showTopics={{@showTopics}}
                  />
                {{/each}}
              </div>
            {{else}}
              <table
                class="category-list
                  {{if @showTopics 'with-topics'}}
                  {{unless this.showMutedCategories 'hidden'}}"
              >
                <thead>
                  <tr>
                    <th class="category"><span
                        aria-level="2"
                        id="categories-only-category-muted"
                        role="heading"
                      >{{i18n "categories.category"}}</span></th>
                    <th class="topics">{{i18n "categories.topics"}}</th>
                    {{#if @showTopics}}
                      <th class="latest">{{i18n "categories.latest"}}</th>
                    {{/if}}
                  </tr>
                </thead>
                <tbody aria-labelledby="categories-only-category-muted">
                  {{#each @categories as |category|}}
                    <ParentCategoryRow
                      @category={{category}}
                      @listType="muted"
                      @showTopics={{@showTopics}}
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
      @connectorTagName="div"
      @name="below-categories-only"
      @outletArgs={{lazyHash categories=@categories showTopics=@showTopics}}
    />
  </template>
}
