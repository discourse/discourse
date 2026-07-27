import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import {
  allCategories,
  CATEGORIES,
  STYLEGUIDE_PANEL,
} from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default {
  name: "styleguide-sidebar",

  initialize() {
    withPluginApi((api) => {
      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class extends BaseCustomSidebarPanel {
            key = STYLEGUIDE_PANEL;
            hidden = true;
            displayHeader = true;
            expandActiveSection = true;
            scrollActiveLinkIntoView = true;
            filterable = true;
          }
      );

      CATEGORIES.forEach((categoryId) => {
        api.addSidebarSection(
          (BaseCustomSidebarSection, BaseCustomSidebarSectionLink) => {
            class StyleguideSectionLink extends BaseCustomSidebarSectionLink {
              constructor(section) {
                super(...arguments);
                this.section = section;
              }

              get name() {
                return this.section.id;
              }

              get route() {
                return "styleguide.show";
              }

              get models() {
                return [this.section.category, this.section.id];
              }

              get text() {
                return i18n(
                  `styleguide.sections.${this.section.id.replaceAll("-", "_")}.title`
                );
              }

              get title() {
                return this.text;
              }
            }

            return class extends BaseCustomSidebarSection {
              get name() {
                return `styleguide-${categoryId}`;
              }

              get text() {
                return i18n(`styleguide.categories.${categoryId}`);
              }

              get links() {
                const category = allCategories().find(
                  (c) => c.id === categoryId
                );

                return (category?.sections ?? []).map(
                  (section) => new StyleguideSectionLink(section)
                );
              }
            };
          },
          STYLEGUIDE_PANEL
        );
      });
    });
  },
};
