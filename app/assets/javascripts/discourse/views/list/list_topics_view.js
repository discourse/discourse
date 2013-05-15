/**
  This view handles the rendering of a topic list

  @class ListTopicsView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.Scrolling
  @module Discourse
**/
Discourse.ListTopicsView = Discourse.View.extend(Discourse.Scrolling, {
  templateName: 'list/topics',
  categoryBinding: 'controller.controllers.list.category',
  canCreateTopicBinding: 'controller.controllers.list.canCreateTopic',
  loadedMore: false,
  currentTopicId: null,

  insertedCount: (function() {
    var inserted;
    inserted = this.get('controller.inserted');
    if (!inserted) {
      return 0;
    }
    return inserted.length;
  }).property('controller.inserted.@each'),

  rollUp: (function() {
    return this.get('insertedCount') > Discourse.SiteSettings.new_topics_rollup;
  }).property('insertedCount'),

  willDestroyElement: function() {
    this.unbindScrolling();
  },

  allLoaded: (function() {
    return !this.get('loading') && !this.get('controller.content.more_topics_url');
  }).property('loading', 'controller.content.more_topics_url'),

  didInsertElement: function() {
    var eyeline, scrollPos,
      _this = this;
    this.bindScrolling();
    eyeline = new Discourse.Eyeline('.topic-list-item');
    eyeline.on('sawBottom', function() {
      return _this.loadMore();
    });
    if (scrollPos = Discourse.get('transient.topicListScrollPos')) {
      Em.run.next(function() {
        return $('html, body').scrollTop(scrollPos);
      });
    } else {
      Em.run.next(function() {
        return $('html, body').scrollTop(0);
      });
    }
    this.set('eyeline', eyeline);
    return this.set('currentTopicId', null);
  },

  loadMore: function() {
    if (this.get('loading')) return;
    this.set('loading', true);

    var listTopicsView = this;
    var promise = this.get('controller.content').loadMoreTopics();
    if (promise) {
      promise.then(function(hasMoreResults) {
        listTopicsView.set('loadedMore', true);
        listTopicsView.set('loading', false);
        Em.run.next(function() { listTopicsView.saveScrollPos(); });
        if (!hasMoreResults) {
          listTopicsView.get('eyeline').flushRest();
        }
      });
    } else {
      this.set('loading', false);
    }
  },

  // Remember where we were scrolled to
  saveScrollPos: function() {
    return Discourse.set('transient.topicListScrollPos', $(window).scrollTop());
  },

  // When the topic list is scrolled
  scrolled: function(e) {
    var _ref;
    this.saveScrollPos();
    return (_ref = this.get('eyeline')) ? _ref.update() : void 0;
  },

  footerMessage: function() {
    var content, split;
    if (!this.get('allLoaded')) {
      return;
    }
    content = this.get('category');
    if( content ) {
      return Em.String.i18n('topics.bottom.category', {category: content.get('name')});
    } else {
      content = this.get('controller.content');
      split = content.get('filter').split('/');
      if (content.get('topics.length') === 0) {
        return Em.String.i18n("topics.none." + split[0], {
          category: split[1]
        });
      } else {
        return Em.String.i18n("topics.bottom." + split[0], {
          category: split[1]
        });
      }
    }
  }.property('allLoaded', 'controller.content.topics.length')

});


