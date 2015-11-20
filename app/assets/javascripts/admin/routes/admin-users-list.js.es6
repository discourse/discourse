import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';

export default Discourse.Route.extend({

  actions: {
    exportUsers() {
      exportEntity('user_list').then(outputExportResult);
    },

    sendInvites() {
      this.transitionTo('userInvited', Discourse.User.current());
    },

    deleteUser(user) {
      Discourse.AdminUser.create(user).destroy({ deletePosts: true });
    }
  }

});
