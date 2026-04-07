/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
//  A breadcrumb including category drop downs
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryVariables from "discourse/helpers/category-variables";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import CategoryDrop from "discourse/select-kit/components/category-drop";
import TagDrop from "discourse/select-kit/components/tag-drop";
import TagsIntersectionChooser from "discourse/select-kit/components/tags-intersection-chooser";
import deprecatedOutletArgument from "../helpers/deprecated-outlet-argument";

@tagName("")
export default class BreadCrumbs extends Component {
  editingCategory = false;
  editingCategoryTab = null;

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
  get hidden() {
    return this.site.mobileView && !this.category;
  }

  <template>
    <ol
      class={{concatClass "category-breadcrumb" (if this.hidden "hidden")}}
      ...attributes
    >
      <PluginOutlet
        @name="bread-crumbs-left"
        @connectorTagName="li"
        @outletArgs={{lazyHash
          tag=this.tag
          additionalTags=this.additionalTags
          noSubcategories=this.noSubcategories
          showTagsSection=this.showTagsSection
          currentCategory=this.category
          categoryBreadcrumbs=this.categoryBreadcrumbs
          editingCategory=this.editingCategory
          editingCategoryTab=this.editingCategoryTab
        }}
        @deprecatedArgs={{lazyHash
          tagId=(deprecatedOutletArgument
            value=this.tag.name
            message="The argument 'tagId' is deprecated on the outlet 'bread-crumbs-left', use 'tag.name' instead"
            id="discourse.plugin-connector.deprecated-arg.bread-crumbs-left"
            since="2025.12.0-latest"
            silence="discourse.header-service-topic"
          )
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
              @tag={{this.tag}}
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
              @mainTag={{this.tag}}
              @additionalTags={{this.additionalTags}}
              @options={{hash categoryId=this.category.id}}
            />
          </li>
        {{else}}
          <li>
            <TagDrop
              @currentCategory={{this.category}}
              @noSubcategories={{this.noSubcategories}}
              @tag={{this.tag}}
            />
          </li>
        {{/if}}
      {{/if}}

      <PluginOutlet
        @name="bread-crumbs-right"
        @connectorTagName="li"
        @outletArgs={{lazyHash
          tag=this.tag
          additionalTags=this.additionalTags
          noSubcategories=this.noSubcategories
          showTagsSection=this.showTagsSection
          currentCategory=this.category
          categoryBreadcrumbs=this.categoryBreadcrumbs
          editingCategory=this.editingCategory
          editingCategoryTab=this.editingCategoryTab
        }}
        @deprecatedArgs={{lazyHash
          tagId=(deprecatedOutletArgument
            value=this.tag.name
            message="The argument 'tagId' is deprecated on the outlet 'bread-crumbs-right', use 'tag.name' instead"
            id="discourse.plugin-connector.deprecated-arg.bread-crumbs-right"
            since="2025.12.0-latest"
            silence="discourse.header-service-topic"
          )
        }}
      />
    </ol>
  </template>
}
