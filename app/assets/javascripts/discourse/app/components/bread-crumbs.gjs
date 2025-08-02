import Component from "@ember/component";
import { hash } from "@ember/helper";
import { filter } from "@ember/object/computed";
import { classNameBindings, tagName } from "@ember-decorators/component";
//  A breadcrumb including category drop downs
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryVariables from "discourse/helpers/category-variables";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import CategoryDrop from "select-kit/components/category-drop";
import TagDrop from "select-kit/components/tag-drop";
import TagsIntersectionChooser from "select-kit/components/tags-intersection-chooser";

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

  @discourseComputed("category", "categories", "noSubcategories")
  categoryBreadcrumbs(category, filteredCategories, noSubcategories) {
    const ancestors = category?.ancestors || [];
    const parentCategories = [undefined, ...ancestors];
    const categories = [...ancestors, undefined];

    return parentCategories
      .map((x, i) => [x, categories[i]])
      .map((record) => {
        const [parentCategory, subCategory] = record;

        const options = filteredCategories.filter(
          (c) =>
            c.get("parentCategory.id") === (parentCategory && parentCategory.id)
        );

        return {
          category: subCategory,
          parentCategory,
          options,
          isSubcategory: !!parentCategory,
          noSubcategories: !subCategory && noSubcategories,
          hasOptions: !parentCategory || parentCategory.has_children,
        };
      });
  }

  @discourseComputed("siteSettings.tagging_enabled", "editingCategory")
  showTagsSection(taggingEnabled, editingCategory) {
    return taggingEnabled && !editingCategory;
  }

  @discourseComputed("category")
  parentCategory(category) {
    deprecated(
      "The parentCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategory" }
    );
    return category && category.parentCategory;
  }

  @discourseComputed("parentCategories")
  parentCategoriesSorted(parentCategories) {
    deprecated(
      "The parentCategoriesSorted property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.parentCategoriesSorted" }
    );
    if (this.siteSettings.fixed_category_positions) {
      return parentCategories;
    }

    return parentCategories.sortBy("totalTopicCount").reverse();
  }

  @discourseComputed("category")
  hidden(category) {
    return this.site.mobileView && !category;
  }

  @discourseComputed("category", "parentCategory")
  firstCategory(category, parentCategory) {
    deprecated(
      "The firstCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.firstCategory" }
    );
    return parentCategory || category;
  }

  @discourseComputed("category", "parentCategory")
  secondCategory(category, parentCategory) {
    deprecated(
      "The secondCategory property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.secondCategory" }
    );
    return parentCategory && category;
  }

  @discourseComputed("firstCategory", "hideSubcategories")
  childCategories(firstCategory, hideSubcategories) {
    deprecated(
      "The childCategories property of the bread-crumbs component is deprecated",
      { id: "discourse.breadcrumbs.childCategories" }
    );
    if (hideSubcategories) {
      return [];
    }

    if (!firstCategory) {
      return [];
    }

    return this.categories.filter(
      (c) => c.get("parentCategory") === firstCategory
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
              autoFilterable=true
              shouldDisplayIcon=false
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
