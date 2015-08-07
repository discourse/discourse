import { propertyEqual } from 'discourse/lib/computed';
import BufferedContent from 'discourse/mixins/buffered-content';
import { popupAjaxError } from 'discourse/lib/ajax-error';

function updateState(state, opts) {
  opts = opts || {};

  return function() {
    const post = this.get('post');
    const args = { state };

    if (opts.deleteUser) { args.delete_user = true; }

    post.update(args).then(() => {
      this.get('controllers.queued-posts.model').removeObject(post);
    }).catch(popupAjaxError);
  };
}

export default Ember.Controller.extend(BufferedContent, {
  needs: ['queued-posts'],
  post: Ember.computed.alias('model'),
  currentlyEditing: Ember.computed.alias('controllers.queued-posts.editing'),

  editing: propertyEqual('model', 'currentlyEditing'),

  _confirmDelete: updateState('rejected', {deleteUser: true}),

  actions: {
    approve: updateState('approved'),
    reject: updateState('rejected'),

    deleteUser() {
      bootbox.confirm(I18n.t('queue.delete_prompt', {username: this.get('model.user.username')}), (confirmed) => {
        if (confirmed) { this._confirmDelete(); }
      });
    },

    edit() {
      // This is stupid but pagedown cannot be on the screen twice or it will break
      this.set('currentlyEditing', null);
      Ember.run.scheduleOnce('afterRender', () => this.set('currentlyEditing', this.get('model')));
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
