import UrlRefresh from 'discourse/mixins/url-refresh';
import ScrollTop from 'discourse/mixins/scroll-top';

export default Discourse.View.extend(UrlRefresh, ScrollTop, {
  _addBodyClass: function() {
    $('body').addClass('categories-list');
  }.on('didInsertElement'),

  _removeBodyClass: function() {
    $('body').removeClass('categories-list');
  }.on('willDestroyElement')
});
