import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  tagName: "li",
  classNameBindings: ['topicStatusIcon'],

  @computed('topic.pinned', 'topic.closed', 'topic.archived')
  topicStatusIcon() {
    if(this.get('topic.pinned'))   { return 'topic-pinned'; }
    if(this.get('topic.closed'))   { return 'topic-closed'; }
    if(this.get('topic.archived')) { return 'topic-archived'; }
    return 'topic-open';
  }
});
