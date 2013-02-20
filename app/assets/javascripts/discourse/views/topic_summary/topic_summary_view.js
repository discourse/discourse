(function() {

  window.Discourse.TopicSummaryView = Ember.ContainerView.extend(Discourse.Presence, {
    topicBinding: 'controller.content',
    classNameBindings: ['hidden', ':topic-summary'],
    LINKS_SHOWN: 5,
    collapsed: true,
    allLinksShown: false,
    showAllLinksControls: (function() {
      if (this.blank('topic.links')) {
        return false;
      }
      if (this.get('allLinksShown')) {
        return false;
      }
      if (this.get('topic.links.length') <= this.LINKS_SHOWN) {
        return false;
      }
      return true;
    }).property('allLinksShown', 'topic.links'),
    infoLinks: (function() {
      var allLinks;
      if (this.blank('topic.links')) {
        return [];
      }
      allLinks = this.get('topic.links');
      if (this.get('allLinksShown')) {
        return allLinks;
      }
      return allLinks.slice(0, this.LINKS_SHOWN);
    }).property('topic.links', 'allLinksShown'),
    newPostCreated: (function() {
      return this.rerender();
    }).observes('topic.posts_count'),
    hidden: (function() {
      if (this.get('post.post_number') !== 1) {
        return true;
      }
      if (this.get('controller.content.archetype') === 'private_message') {
        return false;
      }
      if (this.get('controller.content.archetype') !== 'regular') {
        return true;
      }
      return this.get('controller.content.posts_count') < 2;
    }).property(),
    init: function() {
      this._super();
      if (this.get('hidden')) {
        return;
      }
      this.pushObject(Em.View.create({
        templateName: 'topic_summary/info',
        topic: this.get('topic'),
        summaryView: this
      }));
      return this.trigger('appendSummaryInformation', this);
    },
    toggleMore: function() {
      return this.toggleProperty('collapsed');
    },
    showAllLinks: function() {
      return this.set('allLinksShown', true);
    },
    appendSummaryInformation: function(container) {
      /* If we have a best of view
      */
      if (this.get('controller.showBestOf')) {
        container.pushObject(Discourse.View.create({
          templateName: 'topic_summary/best_of_toggle',
          tagName: 'section',
          classNames: ['information']
        }));
      }
      /* If we have a private message
      */

      if (this.get('topic.isPrivateMessage')) {
        return container.pushObject(Discourse.View.create({
          templateName: 'topic_summary/private_message',
          tagName: 'section',
          classNames: ['information']
        }));
      }
    }
  });

}).call(this);
