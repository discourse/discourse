import { relativeAge } from 'discourse/lib/formatter';

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
  'split_topic': 'sign-out'
};

export function actionDescription(actionCode, createdAt) {
  return function() {
    const ac = this.get(actionCode);
    if (ac) {
      const dt = new Date(this.get(createdAt));
      const when =  relativeAge(dt, {format: 'medium-with-ago'});
      return I18n.t(`action_codes.${ac}`, {when}).htmlSafe();
    }
  }.property(actionCode, createdAt);
}

export default Ember.Component.extend({
  layoutName: 'components/small-action', // needed because `time-gap` inherits from this
  classNames: ['small-action'],

  description: actionDescription('actionCode', 'post.created_at'),

  icon: function() {
    return icons[this.get('actionCode')] || 'exclamation';
  }.property('actionCode'),

  actions: {
    edit: function() {
      this.sendAction('editPost', this.get('post'));
    },

    delete: function() {
      this.sendAction('deletePost', this.get('post'));
    }
  }

});
