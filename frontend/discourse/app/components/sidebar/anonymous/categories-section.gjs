import { cached } from "@glimmer/tracking";
import { service } from "@ember/service";
import { findActiveLink } from "discourse/lib/sidebar/active-link";
import { applyValueTransformer } from "discourse/lib/transformer";
import Category from "discourse/models/category";
import { and, eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import AllCategoriesSectionLink from "../common/all-categories-section-link";
import SidebarCommonCategoriesSection from "../common/categories-section";
import Section from "../section";
import SectionLink from "../section-link";

export default class SidebarAnonymousCategoriesSection extends SidebarCommonCategoriesSection {
  @service router;

  shouldSortCategoriesByDefault = this.#defaultCategoryIds().length > 0;

  @cached
  get activeLink() {
    return findActiveLink(this.sectionLinks, this.router);
  }

  get categories() {
    const ids = this.#defaultCategoryIds();
    if (ids.length) {
      return Category.findByIds(ids);
    }
    return this.topSiteCategories;
  }

  #defaultCategoryIds() {
    const raw = this.siteSettings.default_navigation_menu_categories;
    const initial = raw ? raw.split("|").map((id) => parseInt(id, 10)) : [];

    return applyValueTransformer(
      "sidebar-anonymous-default-categories",
      initial
    );
  }

  <template>
    <Section
      @sectionName="categories"
      @activeLink={{this.activeLink}}
      @expandWhenActive={{@expandActiveSection}}
      @headerLinkText={{i18n "sidebar.sections.categories.header_link_text"}}
      @collapsable={{@collapsable}}
    >
      {{#each this.sectionLinks as |sectionLink|}}
        <SectionLink
          @scrollIntoView={{and
            @scrollActiveLinkIntoView
            (eq sectionLink.name this.activeLink.name)
          }}
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

      <AllCategoriesSectionLink
        @scrollActiveLinkIntoView={{@scrollActiveLinkIntoView}}
      />
    </Section>
  </template>
}
