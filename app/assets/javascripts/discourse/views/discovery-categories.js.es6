import UrlRefresh from 'discourse/mixins/url-refresh';

export default Ember.View.extend(UrlRefresh, {
  _addBodyClass: function() {
    $('body').addClass('categories-list');
  }.on('didInsertElement'),

  _removeBodyClass: function() {
    $('body').removeClass('categories-list');
  }.on('willDestroyElement')
});
