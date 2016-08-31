import { default as computed, observes, on } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: 'table',
  classNames: ['topic-list'],
  showTopicPostBadges: true,

  _init: function(){
    this.addObserver('hideCategory', this.rerender);
    this.addObserver('order', this.rerender);
    this.addObserver('ascending', this.rerender);
  }.on('init'),

  toggleInTitle: function(){
    return !this.get('bulkSelectEnabled') && this.get('canBulkSelect');
  }.property('bulkSelectEnabled'),

  sortable: function(){
    return !!this.get('changeSort');
  }.property(),

  skipHeader: function() {
    return this.site.mobileView;
  }.property(),

  showLikes: function(){
    return this.get('order') === "likes";
  }.property('order'),

  showOpLikes: function(){
    return this.get('order') === "op_likes";
  }.property('order'),

  @computed('topics.@each', 'order', 'ascending')
  lastVisitedTopic(topics, order, ascending) {
    if (!this.get('highlightLastVisited')) { return; }
    if (order !== "default" && order !== "activity") { return; }
    if (!topics || topics.length === 1) { return; }
    if (ascending) { return; }

    let user = Discourse.User.current();
    if (!user || !user.previous_visit_at) {
      return;
    }

    let prevTopic, topic;

    prevTopic = this.get('prevTopic');

    if (prevTopic) {
      return prevTopic;
    }

    let prevVisit = user.get('previousVisitAt');

    // this is more efficient cause we keep appending to list
    // work backwards
    let start = 0;
    while(topics[start] && topics[start].get('pinned')) {
      start++;
    }

    let i;
    for(i=topics.length-1;i>=start;i--){
      if (topics[i].get('bumpedAt') > prevVisit) {
        prevTopic = topics[i];
        break;
      }
      topic = topics[i];
    }

    if (!prevTopic || !topic) {
      return;
    }

    // end of list that was scanned
    if (topic.get('bumpedAt') > prevVisit) {
      return;
    }

    prevTopic.set('isLastVisited', true);
    this.set('prevTopic', prevTopic);

    return prevTopic;
  },

  @observes('category')
  @on('willDestroyElement')
  _cleanLastVisitedTopic() {
    const prevTopic = this.get('prevTopic');

    if (prevTopic) {
      prevTopic.set('isLastVisited', false);
      this.set('prevTopic', null);
    }
  },

  click(e) {
    var self = this;
    var on = function(sel, callback){
      var target = $(e.target).closest(sel);

      if(target.length === 1){
        callback.apply(self, [target]);
      }
    };

    on('button.bulk-select', function(){
      this.sendAction('toggleBulkSelect');
      this.rerender();
    });

    on('th.sortable', function(e2){
      this.sendAction('changeSort', e2.data('sort-order'));
      this.rerender();
    });
  }
});
