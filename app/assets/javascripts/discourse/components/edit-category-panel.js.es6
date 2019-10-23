import Component from "@ember/component";
const EditCategoryPanel = Component.extend({});

export default EditCategoryPanel;

export function buildCategoryPanel(tab, extras) {
  return EditCategoryPanel.extend(
    {
      activeTab: Ember.computed.equal("selectedTab", tab),
      classNameBindings: [
        ":modal-tab",
        "activeTab::hide",
        `:edit-category-tab-${tab}`
      ]
    },
    extras || {}
  );
}
