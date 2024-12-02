import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import AllCategoriesSectionLink from "../common/all-categories-section-link";
import SidebarCommonCategoriesSection from "../common/categories-section";
import Section from "../section";
import SectionLink from "../section-link";

export default class SidebarAnonymousCategoriesSection extends SidebarCommonCategoriesSection {
  shouldSortCategoriesByDefault =
    !!this.siteSettings.default_navigation_menu_categories;

  get categories() {
    if (this.siteSettings.default_navigation_menu_categories) {
      return Category.findByIds(
        this.siteSettings.default_navigation_menu_categories
          .split("|")
          .map((categoryId) => parseInt(categoryId, 10))
      );
    } else {
      return this.topSiteCategories;
    }
  }

  <template>
    <Section
      @sectionName="categories"
      @headerLinkText={{i18n "sidebar.sections.categories.header_link_text"}}
      @collapsable={{@collapsable}}
    >
      {{#each this.sectionLinks as |sectionLink|}}
        <SectionLink
          @route={{sectionLink.route}}
          @title={{sectionLink.title}}
          @content={{sectionLink.text}}
          @currentWhen={{sectionLink.currentWhen}}
          @model={{sectionLink.model}}
          @prefixType={{sectionLink.prefixType}}
          @prefixValue={{sectionLink.prefixValue}}
          @prefixColor={{sectionLink.prefixColor}}
          data-category-id={{sectionLink.category.id}}
        />
      {{/each}}

      <AllCategoriesSectionLink />
    </Section>
  </template>
}
