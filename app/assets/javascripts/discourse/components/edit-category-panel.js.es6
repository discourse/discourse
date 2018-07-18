const EditCategoryPanel = Ember.Component.extend({});

export default EditCategoryPanel;

export function buildCategoryPanel(tab, extras) {
  return EditCategoryPanel.extend(
    {
      activeTab: Ember.computed.equal("selectedTab", tab),
      classNameBindings: [
        ":modal-tab",
        "activeTab::invisible",
        `:edit-category-tab-${tab}`
      ]
    },
    extras || {}
  );
}
