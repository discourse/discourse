import { ajax } from 'discourse/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  users: null,
  groupId: null,
  saving: false,

  @computed('saving', 'users', 'groupId')
  buttonDisabled(saving, users, groupId) {
    return saving || !groupId || !users || !users.length;
  },

  actions: {
    addToGroup() {
      if (this.get('saving')) { return; }

      const users = this.get('users').split("\n")
                                      .uniq()
                                      .reject(x => x.length === 0);

      this.set('saving', true);
      ajax('/admin/groups/bulk', {
        data: { users, group_id: this.get('groupId') },
        method: 'PUT'
      }).then(() => {
        this.transitionToRoute('adminGroups.bulkComplete');
      }).catch(popupAjaxError).finally(() => {
        this.set('saving', false);
      });

    }
  }
});
