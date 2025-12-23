/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { computed } from "@ember/object";
import { filter } from "@ember/object/computed";
import { compare } from "@ember/utils";
import { classNameBindings, tagName } from "@ember-decorators/component";
//  A breadcrumb including category drop downs
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryVariables from "discourse/helpers/category-variables";
import lazyHash from "discourse/helpers/lazy-hash";
import deprecated from "discourse/lib/deprecated";
import CategoryDrop from "discourse/select-kit/components/category-drop";
import TagDrop from "discourse/select-kit/components/tag-drop";
import TagsIntersectionChooser from "discourse/select-kit/components/tags-intersection-chooser";

@tagName("ol")
@classNameBindings("hidden:hidden", ":category-breadcrumb")
export default class BreadCrumbs extends Component {
  editingCategory = false;
  editingCategoryTab = null;

  @filter("categories", function (c) {
    deprecated(
      "The parentCategories property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategories" }
    );
    if (
      c.id === this.site.get("uncategorized_category_id") &&
      !this.siteSettings.allow_uncategorized_topics
    ) {
      // Don't show "uncategorized" if allow_uncategorized_topics setting is false.
      return false;
    }

    return !c.get("parentCategory");
  })
  parentCategories;

  @computed("category", "categories", "noSubcategories")
  get categoryBreadcrumbs() {
    const ancestors = this.category?.ancestors || [];
    const parentCategories = [undefined, ...ancestors];
    const categories = [...ancestors, undefined];

    return parentCategories
      .map((x, i) => [x, categories[i]])
      .map((record) => {
        const [parentCategory, subCategory] = record;

        const options = this.categories.filter(
          (c) =>
            c.get("parentCategory.id") === (parentCategory && parentCategory.id)
        );

        return {
          category: subCategory,
          parentCategory,
          options,
          isSubcategory: !!parentCategory,
          noSubcategories: !subCategory && this.noSubcategories,
          hasOptions: !parentCategory || parentCategory.has_children,
        };
      });
  }

  @computed("siteSettings.tagging_enabled", "editingCategory")
  get showTagsSection() {
    return this.siteSettings?.tagging_enabled && !this.editingCategory;
  }

  @computed("category")
  get parentCategory() {
    deprecated(
      "The parentCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategory" }
    );
    return this.category && this.category.parentCategory;
  }

  @computed("parentCategories")
  get parentCategoriesSorted() {
    deprecated(
      "The parentCategoriesSorted property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategoriesSorted" }
    );
    if (this.siteSettings.fixed_category_positions) {
      return this.parentCategories;
    }

    return this.parentCategories.sort(
      (a, b) => compare(b?.totalTopicCount, a?.totalTopicCount) // sort descending
    );
  }

  @computed("category")
  get hidden() {
    return this.site.mobileView && !this.category;
  }

  @computed("category", "parentCategory")
  get firstCategory() {
    deprecated(
      "The firstCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.firstCategory" }
    );
    return this.parentCategory || this.category;
  }

  @computed("category", "parentCategory")
  get secondCategory() {
    deprecated(
      "The secondCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.secondCategory" }
    );
    return this.parentCategory && this.category;
  }

  @computed("firstCategory", "hideSubcategories")
  get childCategories() {
    deprecated(
      "The childCategories property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.childCategories" }
    );
    if (this.hideSubcategories) {
      return [];
    }

    if (!this.firstCategory) {
      return [];
    }

    return this.categories.filter(
      (c) => c.get("parentCategory") === this.firstCategory
    );
  }

  <template>
    <PluginOutlet
      @name="bread-crumbs-left"
      @connectorTagName="li"
      @outletArgs={{lazyHash
        tagId=this.tag.id
        additionalTags=this.additionalTags
        noSubcategories=this.noSubcategories
        showTagsSection=this.showTagsSection
        currentCategory=this.category
        categoryBreadcrumbs=this.categoryBreadcrumbs
        editingCategory=this.editingCategory
        editingCategoryTab=this.editingCategoryTab
      }}
    />

    {{#each this.categoryBreadcrumbs as |breadcrumb|}}
      {{#if breadcrumb.hasOptions}}
        <li
          style={{if
            breadcrumb.category
            (categoryVariables breadcrumb.category)
          }}
        >
          <CategoryDrop
            @category={{breadcrumb.category}}
            @categories={{breadcrumb.options}}
            @tagId={{this.tag.id}}
            @editingCategory={{this.editingCategory}}
            @editingCategoryTab={{this.editingCategoryTab}}
            @options={{hash
              parentCategory=breadcrumb.parentCategory
              subCategory=breadcrumb.isSubcategory
              noSubcategories=breadcrumb.noSubcategories
            }}
            class={{if
              breadcrumb.isSubcategory
              "category-breadcrumb__subcategory-selector"
              "category-breadcrumb__category-selector"
            }}
          />
        </li>
      {{/if}}
    {{/each}}

    {{#if this.showTagsSection}}
      {{#if this.additionalTags}}
        <li>
          <TagsIntersectionChooser
            @currentCategory={{this.category}}
            @mainTag={{this.tag.id}}
            @additionalTags={{this.additionalTags}}
            @options={{hash categoryId=this.category.id}}
          />
        </li>
      {{else}}
        <li>
          <TagDrop
            @currentCategory={{this.category}}
            @noSubcategories={{this.noSubcategories}}
            @tagId={{this.tag.id}}
          />
        </li>
      {{/if}}
    {{/if}}

    <PluginOutlet
      @name="bread-crumbs-right"
      @connectorTagName="li"
      @outletArgs={{lazyHash
        tagId=this.tag.id
        additionalTags=this.additionalTags
        noSubcategories=this.noSubcategories
        showTagsSection=this.showTagsSection
        currentCategory=this.category
        categoryBreadcrumbs=this.categoryBreadcrumbs
        editingCategory=this.editingCategory
        editingCategoryTab=this.editingCategoryTab
      }}
    />
  </template>
}
