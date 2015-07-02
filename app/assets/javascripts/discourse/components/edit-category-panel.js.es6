const EditCategoryPanel = Ember.Component.extend({
  classNameBindings: [':modal-tab', 'activeTab::invisible'],
});

export default EditCategoryPanel;

export function buildCategoryPanel(tab, extras) {
  return EditCategoryPanel.extend({
    activeTab: Ember.computed.equal('selectedTab', tab)
  }, extras || {});
}
