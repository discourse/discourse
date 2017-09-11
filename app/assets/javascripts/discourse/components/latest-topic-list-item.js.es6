import { showEntrance } from "discourse/components/topic-list-item";
import computed from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  click: showEntrance,
  attributeBindings: ['topic.id:data-topic-id'],
  classNameBindings: [':latest-topic-list-item', 'topic.archived', 'topic.visited']
});
