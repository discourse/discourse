import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryVariables from "discourse/helpers/category-variables";
import lazyHash from "discourse/helpers/lazy-hash";
import DiscourseURL, {
  getCategoryAndTagUrl,
  getEditCategoryUrl,
} from "discourse/lib/url";
import CategoryDrop from "discourse/select-kit/components/category-drop";
import TagDrop from "discourse/select-kit/components/tag-drop";
import TagsIntersectionChooser from "discourse/select-kit/components/tags-intersection-chooser";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import DSelectCategoryFilter, {
  ALL_CATEGORIES_ID,
  NO_CATEGORIES_ID,
} from "discourse/ui-kit/select/recipes/categories/d-select-category-filter";
import DSelectTagFilter, {
  ALL_TAGS_ID,
  NO_TAG_ID,
} from "discourse/ui-kit/select/recipes/tags/d-select-tag-filter";
import deprecatedOutletArgument from "../helpers/deprecated-outlet-argument.js";

export default class BreadCrumbs extends Component {
  @service site;
  @service siteSettings;

  get editingCategory() {
    return this.args.editingCategory ?? false;
  }

  @cached
  get categoryBreadcrumbs() {
    const ancestors = this.args.category?.ancestors || [];
    const parentCategories = [undefined, ...ancestors];
    const categories = [...ancestors, undefined];

    return parentCategories
      .map((x, i) => [x, categories[i]])
      .map((record) => {
        const [parentCategory, subCategory] = record;

        const options = this.args.categories.filter(
          (c) =>
            c.get("parentCategory.id") === (parentCategory && parentCategory.id)
        );

        return {
          category: subCategory,
          parentCategory,
          options,
          isSubcategory: !!parentCategory,
          noSubcategories: !subCategory && this.args.noSubcategories,
          hasOptions: !parentCategory || parentCategory.has_children,
        };
      });
  }

  get showTagsSection() {
    return this.siteSettings.tagging_enabled && !this.editingCategory;
  }

  get hidden() {
    return this.site.mobileView && !this.args.category;
  }

  get intersectionTags() {
    return [
      ...(this.args.tag ? [this.args.tag] : []),
      ...(this.args.additionalTags ?? []).map((name) => ({ name })),
    ];
  }

  @action
  changeCategory(breadcrumb, value) {
    const category =
      value === ALL_CATEGORIES_ID || value === NO_CATEGORIES_ID
        ? breadcrumb.parentCategory
        : value;
    const includeSubcategories = value !== NO_CATEGORIES_ID;
    DiscourseURL.routeToUrl(
      this.args.editingCategoryTab
        ? getEditCategoryUrl(
            category,
            includeSubcategories,
            this.args.editingCategoryTab
          )
        : getCategoryAndTagUrl(category, includeSubcategories, this.args.tag)
    );
  }

  @action
  changeIntersection(tags) {
    const main = this.args.tag;
    const names = tags.map((tag) => tag.name);
    DiscourseURL.routeTo(this.#intersectionUrl(main, names));
  }

  @action
  changeTag(tag) {
    let target = tag.target_tag ?? tag;
    if (tag === NO_TAG_ID) {
      target = "none";
    } else if (tag === ALL_TAGS_ID) {
      target = null;
    }
    DiscourseURL.routeToUrl(
      getCategoryAndTagUrl(
        this.args.category,
        !this.args.noSubcategories,
        target
      )
    );
  }

  #intersectionUrl(main, names) {
    if (main && names.includes(main.name)) {
      const remaining = names.filter((name) => name !== main.name);
      if (remaining.length) {
        return `/tags/intersection/${main.name}/${remaining.join("/")}`;
      }
      if (main.id) {
        return `/tag/${main.slug || `${main.id}-tag`}/${main.id}`;
      }
      return `/tag/${main.name}`;
    }
    if (names.length >= 2) {
      return `/tags/intersection/${names.join("/")}`;
    }
    if (names.length) {
      return `/tag/${names[0]}`;
    }
    return "/tags";
  }

  <template>
    <ol
      class={{dConcatClass "category-breadcrumb" (if this.hidden "hidden")}}
      ...attributes
    >
      <PluginOutlet
        @connectorTagName="li"
        @deprecatedArgs={{lazyHash
          tagId=(deprecatedOutletArgument
            value=@tag.name
            message="The argument 'tagId' is deprecated on the outlet 'bread-crumbs-left', use 'tag.name' instead"
            id="discourse.plugin-connector.deprecated-arg.bread-crumbs-left"
            since="2025.12.0-latest"
            silence="discourse.header-service-topic"
          )
        }}
        @name="bread-crumbs-left"
        @outletArgs={{lazyHash
          tag=@tag
          additionalTags=@additionalTags
          noSubcategories=@noSubcategories
          showTagsSection=this.showTagsSection
          currentCategory=@category
          categoryBreadcrumbs=this.categoryBreadcrumbs
          editingCategory=this.editingCategory
          editingCategoryTab=@editingCategoryTab
        }}
      />

      {{#each this.categoryBreadcrumbs key="parentCategory.id" as |breadcrumb|}}
        {{#if breadcrumb.hasOptions}}
          <li
            style={{if
              breadcrumb.category
              (categoryVariables breadcrumb.category)
            }}
          >
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
            {{#if this.siteSettings.enable_new_select_controls}}
              <DSelectCategoryFilter
                class={{if
                  breadcrumb.isSubcategory
                  "category-breadcrumb__subcategory-selector"
                  "category-breadcrumb__category-selector"
                }}
                @editing={{this.editingCategory}}
                @identifier="breadcrumb-category"
                @noSubcategories={{breadcrumb.noSubcategories}}
                @onChange={{fn this.changeCategory breadcrumb}}
                @parentCategory={{breadcrumb.parentCategory}}
                @value={{breadcrumb.category}}
              />
            {{else}}
              <CategoryDrop
                class={{if
                  breadcrumb.isSubcategory
                  "category-breadcrumb__subcategory-selector"
                  "category-breadcrumb__category-selector"
                }}
                @categories={{breadcrumb.options}}
                @category={{breadcrumb.category}}
                @editingCategory={{this.editingCategory}}
                @editingCategoryTab={{@editingCategoryTab}}
                @options={{hash
                  parentCategory=breadcrumb.parentCategory
                  subCategory=breadcrumb.isSubcategory
                  noSubcategories=breadcrumb.noSubcategories
                }}
                @tag={{@tag}}
              />
            {{/if}}
          </li>
        {{/if}}
      {{/each}}

      {{#if this.showTagsSection}}
        {{#if @additionalTags}}
          <li>
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
            {{#if this.siteSettings.enable_new_select_controls}}
              <DSelectTagFilter
                @categoryId={{@category.id}}
                @multiple={{true}}
                @onChange={{this.changeIntersection}}
                @value={{this.intersectionTags}}
              />
            {{else}}
              <TagsIntersectionChooser
                @additionalTags={{@additionalTags}}
                @currentCategory={{@category}}
                @mainTag={{@tag}}
                @options={{hash categoryId=@category.id}}
              />
            {{/if}}
          </li>
        {{else}}
          <li>
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
            {{#if this.siteSettings.enable_new_select_controls}}
              <DSelectTagFilter
                @categoryId={{@category.id}}
                @onChange={{this.changeTag}}
                @value={{@tag}}
              />
            {{else}}
              <TagDrop
                @currentCategory={{@category}}
                @noSubcategories={{@noSubcategories}}
                @tag={{@tag}}
              />
            {{/if}}
          </li>
        {{/if}}
      {{/if}}

      <PluginOutlet
        @connectorTagName="li"
        @deprecatedArgs={{lazyHash
          tagId=(deprecatedOutletArgument
            value=@tag.name
            message="The argument 'tagId' is deprecated on the outlet 'bread-crumbs-right', use 'tag.name' instead"
            id="discourse.plugin-connector.deprecated-arg.bread-crumbs-right"
            since="2025.12.0-latest"
            silence="discourse.header-service-topic"
          )
        }}
        @name="bread-crumbs-right"
        @outletArgs={{lazyHash
          tag=@tag
          additionalTags=@additionalTags
          noSubcategories=@noSubcategories
          showTagsSection=this.showTagsSection
          currentCategory=@category
          categoryBreadcrumbs=this.categoryBreadcrumbs
          editingCategory=this.editingCategory
          editingCategoryTab=@editingCategoryTab
        }}
      />
    </ol>
  </template>
}
