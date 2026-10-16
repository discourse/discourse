import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryVariables from "discourse/helpers/category-variables";
import lazyHash from "discourse/helpers/lazy-hash";
import CategoryDrop from "discourse/select-kit/components/category-drop";
import TagDrop from "discourse/select-kit/components/tag-drop";
import TagsIntersectionChooser from "discourse/select-kit/components/tags-intersection-chooser";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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

      {{#each this.categoryBreadcrumbs as |breadcrumb|}}
        {{#if breadcrumb.hasOptions}}
          <li
            style={{if
              breadcrumb.category
              (categoryVariables breadcrumb.category)
            }}
          >
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
          </li>
        {{/if}}
      {{/each}}

      {{#if this.showTagsSection}}
        {{#if @additionalTags}}
          <li>
            <TagsIntersectionChooser
              @additionalTags={{@additionalTags}}
              @currentCategory={{@category}}
              @mainTag={{@tag}}
              @options={{hash categoryId=@category.id}}
            />
          </li>
        {{else}}
          <li>
            <TagDrop
              @currentCategory={{@category}}
              @noSubcategories={{@noSubcategories}}
              @tag={{@tag}}
            />
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
