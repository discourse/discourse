import { autoUpdatingRelativeAge } from 'discourse/lib/formatter';
import computed from 'ember-addons/ember-computed-decorators';

const icons = {
  'closed.enabled': 'lock',
  'closed.disabled': 'unlock-alt',
  'autoclosed.enabled': 'lock',
  'autoclosed.disabled': 'unlock-alt',
  'archived.enabled': 'folder',
  'archived.disabled': 'folder-open',
  'pinned.enabled': 'thumb-tack',
  'pinned.disabled': 'thumb-tack unpinned',
  'pinned_globally.enabled': 'thumb-tack',
  'pinned_globally.disabled': 'thumb-tack unpinned',
  'visible.enabled': 'eye',
  'visible.disabled': 'eye-slash',
  'split_topic': 'sign-out',
  'invited_user': 'plus-circle',
  'removed_user': 'minus-circle'
};

export function actionDescription(actionCode, createdAt, username) {
  return function() {
    const ac = this.get(actionCode);
    if (ac) {
      const dt = new Date(this.get(createdAt));
      const when = autoUpdatingRelativeAge(dt, { format: 'medium-with-ago' });
      const u = this.get(username);
      const who = u ? `<a class="mention" href="/users/${u}">@${u}</a>` : "";
      return I18n.t(`action_codes.${ac}`, { who, when }).htmlSafe();
    }
  }.property(actionCode, createdAt);
}

export default Ember.Component.extend({
  layoutName: 'components/small-action', // needed because `time-gap` inherits from this
  classNames: ['small-action'],

  description: actionDescription('actionCode', 'post.created_at', 'post.action_code_who'),

  @computed("actionCode")
  icon(actionCode) {
    return icons[actionCode] || 'exclamation';
  },

  actions: {
    edit() {
      this.sendAction('editPost', this.get('post'));
    },

    delete() {
      this.sendAction('deletePost', this.get('post'));
    }
  }

});
