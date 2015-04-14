import { popupAjaxError } from 'discourse/lib/ajax-error';

function updateState(state) {
  return function(post) {
    post.update({ state }).then(() => {
      this.get('model').removeObject(post);
    }).catch(popupAjaxError);
  };
}

export default Ember.Controller.extend({
  actions: {
    approve: updateState('approved'),
    reject: updateState('rejected')
  }
});
