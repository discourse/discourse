/**
  This view handles rendering of the summary of the topic under the first post

  @class TopicSummaryView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicSummaryView = Discourse.ContainerView.extend({
  classNameBindings: ['hidden', ':topic-summary'],
  allLinksShown: false,

  topic: Em.computed.alias('controller.model'),

  showAllLinksControls: function() {
    if (this.get('allLinksShown')) return false;
    if ((this.get('topic.details.links.length') || 0) <= Discourse.TopicSummaryView.LINKS_SHOWN) return false;
    return true;
  }.property('allLinksShown', 'topic.details.links'),

  infoLinks: function() {
    if (this.blank('topic.details.links')) return [];

    var allLinks = this.get('topic.details.links');
    if (this.get('allLinksShown')) return allLinks;
    return allLinks.slice(0, Discourse.TopicSummaryView.LINKS_SHOWN);
  }.property('topic.details.links', 'allLinksShown'),

  shouldRerender: Discourse.View.renderIfChanged('topic.posts_count'),

  hidden: function() {
    if (!this.get('post.firstPost')) return true;
    if (this.get('controller.content.archetype') === 'private_message') return false;
    if (this.get('controller.content.archetype') !== 'regular') return true;
    return this.get('controller.content.posts_count') < 2;
  }.property(),

  init: function() {
    this._super();
    if (this.get('hidden')) return;

    this.attachViewWithArgs({
      templateName: 'topic_summary/info',
      content: this.get('controller')
    }, Discourse.GroupedView);

    this.trigger('appendSummaryInformation', this);
  },

  showAllLinks: function() {
    this.set('allLinksShown', true);
  },

  appendSummaryInformation: function(container) {

    // If we have a best of view
    if (this.get('controller.has_best_of')) {
      container.attachViewWithArgs({
        templateName: 'topic_summary/best_of_toggle',
        tagName: 'section',
        classNames: ['information'],
        content: this.get('controller')
      }, Discourse.GroupedView);
    }

    // If we have a private message
    if (this.get('topic.isPrivateMessage')) {
      container.attachViewWithArgs({
        templateName: 'topic_summary/private_message',
        tagName: 'section',
        classNames: ['information'],
        content: this.get('controller')
      }, Discourse.GroupedView);
    }
  }
});

Discourse.TopicSummaryView.reopenClass({
  LINKS_SHOWN: 5
});
