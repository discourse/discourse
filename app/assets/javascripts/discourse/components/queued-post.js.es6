import { propertyEqual } from 'discourse/lib/computed';
import { default as computed } from 'ember-addons/ember-computed-decorators';
import { bufferedProperty } from 'discourse/mixins/buffered-content';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { cookAsync } from 'discourse/lib/text';

function updateState(state, opts) {
  opts = opts || {};

  return function() {
    const post = this.get('post');
    const args = { state };

    if (opts.deleteUser) { args.delete_user = true; }

    post.update(args).then(() => {
      this.sendAction('removePost', post);
    }).catch(popupAjaxError);
  };
}

export default Ember.Component.extend(bufferedProperty('post'), {
  editing: propertyEqual('post', 'currentlyEditing'),
  _confirmDelete: updateState('rejected', {deleteUser: true}),

  @computed('post.raw')
  cooked(raw) {
    cookAsync(raw).then(cooked => this.set('cooked', cooked));
    return raw;
  },

  actions: {
    approve: updateState('approved'),
    reject: updateState('rejected'),

    deleteUser() {
      bootbox.confirm(I18n.t('queue.delete_prompt', {username: this.get('post.user.username')}), (confirmed) => {
        if (confirmed) { this._confirmDelete(); }
      });
    },

    edit() {
      // This is stupid but pagedown cannot be on the screen twice or it will break
      this.set('currentlyEditing', null);
      Ember.run.scheduleOnce('afterRender', () => this.set('currentlyEditing', this.get('post')));
    },

    confirmEdit() {
      this.get('post').update({ raw: this.get('buffered.raw') }).then(() => {
        this.commitBuffer();
        this.set('currentlyEditing', null);
      });
    },

    cancelEdit() {
      this.rollbackBuffer();
      this.set('currentlyEditing', null);
    }
  }
});
