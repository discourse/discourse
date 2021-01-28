import Component from "@ember/component";
import { equal } from "@ember/object/computed";
const EditCategoryPanel = Component.extend({});

export default EditCategoryPanel;

export function buildCategoryPanel(tab, extras) {
  return EditCategoryPanel.extend(
    {
      activeTab: equal("selectedTab", tab),
      classNameBindings: [
        ":edit-category-tab",
        "activeTab::hide",
        `:edit-category-tab-${tab}`,
      ],
    },
    extras || {}
  );
}
