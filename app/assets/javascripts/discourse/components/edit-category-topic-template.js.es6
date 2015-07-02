import { buildCategoryPanel } from 'discourse/components/edit-category-panel';

export default buildCategoryPanel('topic-template', {
  _activeTabChanged: function() {
    if (this.get('activeTab')) {
      Ember.run.schedule('afterRender', function() {
        $('#wmd-input').focus();
      });
    }
  }.observes('activeTab')
});
