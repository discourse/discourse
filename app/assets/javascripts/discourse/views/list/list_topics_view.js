(function() {

  window.Discourse.ListTopicsView = Ember.View.extend(Discourse.Scrolling, Discourse.Presence, {
    templateName: 'list/topics',
    categoryBinding: 'Discourse.router.listController.category',
    filterModeBinding: 'Discourse.router.listController.filterMode',
    canCreateTopicBinding: 'controller.controllers.list.canCreateTopic',
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
    loadedMore: false,
    currentTopicId: null,
    willDestroyElement: function() {
      return this.unbindScrolling();
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
          return jQuery('html, body').scrollTop(scrollPos);
        });
      } else {
        Em.run.next(function() {
          return jQuery('html, body').scrollTop(0);
        });
      }
      this.set('eyeline', eyeline);
      return this.set('currentTopicId', null);
    },
    loadMore: function() {
      var _this = this;
      if (this.get('loading')) {
        return;
      }
      this.set('loading', true);
      return this.get('controller.content').loadMoreTopics().then(function(hasMoreResults) {
        _this.set('loadedMore', true);
        _this.set('loading', false);
        Em.run.next(function() {
          return _this.saveScrollPos();
        });
        if (!hasMoreResults) {
          return _this.get('eyeline').flushRest();
        }
      });
    },
    /* Remember where we were scrolled to
    */

    saveScrollPos: function() {
      return Discourse.set('transient.topicListScrollPos', jQuery(window).scrollTop());
    },
    /* When the topic list is scrolled
    */

    scrolled: function(e) {
      var _ref;
      this.saveScrollPos();
      return (_ref = this.get('eyeline')) ? _ref.update() : void 0;
    },
    footerMessage: (function() {
      var content, split;
      if (!this.get('allLoaded')) {
        return;
      }
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
    }).property('allLoaded', 'controller.content.topics.length')
  });

}).call(this);
