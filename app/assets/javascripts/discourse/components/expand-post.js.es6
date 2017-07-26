import { ajax } from 'discourse/lib/ajax';

export default Ember.Component.extend({
  tagName: '',

  actions: {
    expandItem() {
      const item = this.get('item');
      const topicId = item.get('topic_id');
      const postNumber = item.get('post_number');

      return ajax(`/posts/by_number/${topicId}/${postNumber}.json`).then(result => {
        item.set('truncated', false);
        item.set('excerpt', result.cooked);
      });
    }
  }
});

