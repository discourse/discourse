import ModalFunctionality from 'discourse/mixins/modal-functionality';
import computed from 'ember-addons/ember-computed-decorators';
import { extractError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  loading: false,
  setAsOwner: false,

  @computed('model.usernames')
  disableAddButton(usernames) {
    return !usernames || !(usernames.length > 0);
  },

  actions: {
    addMembers() {
      const model = this.get('model');
      const usernames = model.get('usernames');
      if (Em.isEmpty(usernames)) { return; }
      let promise;

      if (this.get('setAsOwner')) {
        promise = model.addOwners(usernames, true);
      } else {
        promise = model.addMembers(usernames, true);
      }

      promise.then(() => {
        this.transitionToRoute(
          "group.members",
          this.get('model.name'),
          { queryParams: { filter: usernames } }
        );
        model.set("usernames", null);
        this.send('closeModal');
      })
      .catch(error => this.flash(extractError(error), 'error'));
    },
  },
});
