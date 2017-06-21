import { propertyEqual } from 'discourse/lib/computed';
import { actionDescription } from "discourse/components/small-action";
import { ajax } from 'discourse/lib/ajax';

export default Ember.Component.extend({
  classNameBindings: [":item", "item.hidden", "item.deleted:deleted", "moderatorAction"],
  moderatorAction: propertyEqual("item.post_type", "site.post_types.moderator_action"),
  actionDescription: actionDescription("item.action_code", "item.created_at", "item.username"),

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
