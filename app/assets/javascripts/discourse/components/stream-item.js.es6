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

      return ajax(`/posts/${item.get('post_id')}/cooked.json`).then(result => {
        item.set('truncated', false);
        item.set('excerpt', result.cooked);
      });
    }
  }
});
