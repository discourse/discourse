import BufferedContent from 'discourse/mixins/buffered-content';
import { popupAjaxError } from 'discourse/lib/ajax-error';

function updateState(state) {
  return function() {
    const post = this.get('post');
    post.update({ state }).then(() => {
      this.get('controllers.queued-posts.model').removeObject(post);
    }).catch(popupAjaxError);
  };
}

export default Ember.Controller.extend(BufferedContent, {
  needs: ['queued-posts'],
  post: Ember.computed.alias('model'),

  editing: false,

  actions: {
    approve: updateState('approved'),
    reject: updateState('rejected'),

    edit() {
      this.set('editing', true);
    },

    confirmEdit() {
      this.get('post').update({ raw: this.get('buffered.raw') }).then(() => {
        this.commitBuffer();
        this.set('editing', false);
      });
    },

    cancelEdit() {
      this.rollbackBuffer();
      this.set('editing', false);
    }
  }
});
