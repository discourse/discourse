import { showEntrance } from "discourse/components/topic-list-item";
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  click: showEntrance,
  attributeBindings: ['topic.id:data-topic-id'],
  classNameBindings: [':latest-topic-list-item', 'topic.archived', 'visited'],

  @computed('topic.last_read_post_number', 'topic.highest_post_number')
  visited(lastReadPost, highestPostNumber) {
    return lastReadPost === highestPostNumber;
  },
});
