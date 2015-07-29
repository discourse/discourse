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
  'visible.disabled': 'eye-slash'
};

export default Ember.Component.extend({
  layoutName: 'components/small-action', // needed because `time-gap` inherits from this
  classNames: ['small-action'],

  description: function() {
    const actionCode = this.get('actionCode');
    if (actionCode) {
      const dt = new Date(this.get('post.created_at'));
      const when =  Discourse.Formatter.relativeAge(dt, {format: 'medium-with-ago'});
      const result = I18n.t(`action_codes.${actionCode}`, {when});
      return result + (this.get('post.cooked') || '');
    }
  }.property('actionCode', 'post.created_at', 'post.cooked'),

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
