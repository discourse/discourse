import { cached } from "@glimmer/tracking";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { i18n } from "discourse-i18n";
import { STYLEGUIDE_PANEL } from "../services/styleguide-sidebar";
import { allCategories } from "./styleguide";

function categoryTitle(categoryId) {
  return i18n(`styleguide.categories.${categoryId}`);
}

function sectionTitle(sectionId) {
  return i18n(`styleguide.sections.${sectionId.replace(/-/g, "_")}.title`);
}

class StyleguideSectionLink extends BaseCustomSidebarSectionLink {
  #section;

  constructor({ section }) {
    super(...arguments);
    this.#section = section;
  }

  get name() {
    return `${STYLEGUIDE_PANEL}-section-${this.#section.id}`;
  }

  get route() {
    return "styleguide.show";
  }

  get models() {
    return [this.#section.category, this.#section.id];
  }

  get text() {
    return sectionTitle(this.#section.id);
  }

  get title() {
    return this.text;
  }

  get keywords() {
    // Consulted by the panel filter, which indexes on whole words. The id earns its place
    // because a dasherized id is often what someone types when the title reads differently.
    return {
      navigation: [...this.text.toLowerCase().split(/\s+/), this.#section.id],
    };
  }
}

function buildCategorySection(category) {
  return class StyleguideCategorySection extends BaseCustomSidebarSection {
    get name() {
      return `${STYLEGUIDE_PANEL}-category-${category.id}`;
    }

    get text() {
      return categoryTitle(category.id);
    }

    get title() {
      return this.text;
    }

    get links() {
      return category.sections.map(
        (section) => new StyleguideSectionLink({ section })
      );
    }
  };
}

/**
 * The styleguide's own navigation, rendered as a sidebar panel so it can replace the forum
 * sidebar rather than sit beside it.
 *
 * Sections are built in a getter rather than registered up front, for two reasons. The section
 * list is only complete once every initializer has had its chance to call `addStyleguideSection`,
 * and `allCategories` memoizes on its first call — so reading it early would freeze a list that
 * is still missing entries. Deferring to render time also means no re-registration dance is
 * needed to get the panel to redraw.
 */
const styleguideSidebarPanelBuilder = (BaseCustomSidebarPanel) =>
  class StyleguideSidebarPanel extends BaseCustomSidebarPanel {
    key = STYLEGUIDE_PANEL;
    hidden = true;
    displayHeader = true;
    expandActiveSection = true;
    scrollActiveLinkIntoView = true;
    filterable = true;

    // The sidebar builds a fresh section instance from each of these classes on every render,
    // so caching keeps that from rebuilding the classes themselves as well.
    @cached
    get sections() {
      return allCategories().map(buildCategorySection);
    }
  };

export default styleguideSidebarPanelBuilder;
