/**
  This view handles rendering of the map of the topic under the first post

  @class TopicMapView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/

var LINKS_SHOWN = 5;

Discourse.TopicMapView = Discourse.ContainerView.extend({
  classNameBindings: ['hidden', ':topic-map'],
  allLinksShown: false,

  showAllLinksControls: function() {
    if (this.get('allLinksShown')) return false;
    if ((this.get('topic.details.links.length') || 0) <= LINKS_SHOWN) return false;
    return true;
  }.property('allLinksShown', 'topic.details.links'),

  infoLinks: function() {
    if (this.blank('topic.details.links')) return [];

    var allLinks = this.get('topic.details.links');
    if (this.get('allLinksShown')) return allLinks;
    return allLinks.slice(0, LINKS_SHOWN);
  }.property('topic.details.links', 'allLinksShown'),

  shouldRerender: Discourse.View.renderIfChanged('topic.posts_count'),

  hidden: function() {
    if (!this.get('post.firstPost')) return true;

    var topic = this.get('topic');
    if (topic.get('archetype') === 'private_message') return false;
    if (topic.get('archetype') !== 'regular') return true;
    return topic.get('posts_count') < 2;
  }.property(),

  init: function() {
    this._super();
    if (this.get('hidden')) return;

    this.attachViewWithArgs({
      templateName: 'topic_map/info',
      content: this.get('controller')
    }, Discourse.GroupedView);

    this.trigger('appendMapInformation', this);
  },

  actions: {
    showAllLinks: function() {
      this.set('allLinksShown', true);
    },
  },

  appendMapInformation: function(container) {

    var topic = this.get('topic');

    // If we have a best of capability
    if (topic.get('has_best_of')) {
      container.attachViewWithArgs({ topic: topic }, Discourse.DiscourseToggleBestOfComponent);
    }

    // If we have a private message
    if (this.get('topic.isPrivateMessage')) {
      container.attachViewWithArgs({
        templateName: 'topic_map/private_message',
        tagName: 'section',
        classNames: ['information'],
        content: this.get('controller')
      }, Discourse.GroupedView);
    }
  }
});

