import ModalFunctionality from 'discourse/mixins/modal-functionality';
import computed from 'ember-addons/ember-computed-decorators';
import { extractError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend(ModalFunctionality, {
  loading: false,

  @computed('model.usernames')
  disableAddButton(usernames) {
    return !usernames || !(usernames.length > 0);
  },

  actions: {
    addMembers() {
      if (Em.isEmpty(this.get("model.usernames"))) { return; }

      this.get("model").addMembers(this.get("model.usernames"))
        .then(() => {
          this.transitionToRoute(
            "group.members",
            this.get('model.name'),
            { queryParams: { filter: this.get('model.usernames') } }
          );
          this.set("model.usernames", null);
          this.send('closeModal');
        })
        .catch(error => this.flash(extractError(error), 'error'));
    },
  },
});
