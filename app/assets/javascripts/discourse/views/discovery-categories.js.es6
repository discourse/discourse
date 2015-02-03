import UrlRefresh from 'discourse/mixins/url-refresh';

export default Discourse.View.extend(UrlRefresh, Discourse.ScrollTop, {
  _addBodyClass: function() {
    $('body').addClass('categories-list');
  }.on('didInsertElement'),

  _removeBodyClass: function() {
    $('body').removeClass('categories-list');
  }.on('willDestroyElement')
});
