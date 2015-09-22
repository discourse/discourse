var LINKS_SHOWN = 5;

export default Ember.Component.extend({
  mapCollapsed: true,
  layoutName: 'components/topic-map',
  details: Em.computed.alias('topic.details'),
  allLinksShown: false,

  init: function() {
    this._super();

    // If the topic has a summary, expand the map by default
    this.set('mapCollapsed', Discourse.Mobile.mobileView || (!this.get('topic.has_summary')));
  },

  showPosterAvatar: Em.computed.gt('topic.posts_count', 2),

  toggleMapClass: function() {
    return this.get('mapCollapsed') ? 'chevron-down' : 'chevron-up';
  }.property('mapCollapsed'),

  showAllLinksControls: function() {
    if (this.get('allLinksShown')) return false;
    if ((this.get('details.links.length') || 0) <= LINKS_SHOWN) return false;
    return true;
  }.property('allLinksShown', 'topic.details.links'),

  infoLinks: function() {
    var allLinks = this.get('details.links');
    if (Em.isNone(allLinks)) return [];

    if (this.get('allLinksShown')) return allLinks;
    return allLinks.slice(0, LINKS_SHOWN);

  }.property('details.links', 'allLinksShown'),

  actions: {
    toggleMap: function() {
      this.toggleProperty('mapCollapsed');
    },

    showAllLinks: function() {
      this.set('allLinksShown', true);
    }
  }
});
