const CategoryPanelBase = Ember.Component.extend({
  classNameBindings: [':modal-tab', 'activeTab::invisible'],
});

export default CategoryPanelBase;

export function buildCategoryPanel(tab, extras) {
  return CategoryPanelBase.extend({
    activeTab: Ember.computed.equal('selectedTab', tab)
  }, extras || {});
}
