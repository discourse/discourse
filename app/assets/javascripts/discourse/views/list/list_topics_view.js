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

  willDestroyElement: function() {
    this.unbindScrolling();
  },

  didInsertElement: function() {
    this.bindScrolling();
    var eyeline = new Discourse.Eyeline('.topic-list-item');

    var listTopicsView = this;
    eyeline.on('sawBottom', function() {
      listTopicsView.loadMore();
    });

    var scrollPos = Discourse.get('transient.topicListScrollPos');
    if (scrollPos) {
      Em.run.schedule('afterRender', function() {
        $('html, body').scrollTop(scrollPos);
      });
    } else {
      Em.run.schedule('afterRender', function() {
        $('html, body').scrollTop(0);
      });
    }
    this.set('eyeline', eyeline);
  },

  loadMore: function() {
    var listTopicsView = this;
    listTopicsView.get('controller').loadMore().then(function (hasMoreResults) {
      Em.run.schedule('afterRender', function() {
        listTopicsView.saveScrollPos();
      });
      if (!hasMoreResults) {
        listTopicsView.get('eyeline').flushRest();
      }
    })
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
  }


});


