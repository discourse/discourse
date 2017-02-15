import { getOwner } from 'discourse-common/lib/get-owner';

export default Ember.Component.extend({
  router: function() {
    return getOwner(this).lookup('router:main');
  }.property(),

  active: function() {
    const id = this.get('customization.id');
    return this.get('router.url').indexOf(`/customize/css_html/${id}/css`) !== -1;
  }.property('router.url', 'customization.id')
});
