import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';
import AdminUser from 'admin/models/admin-user';

export default Discourse.Route.extend({

  actions: {
    exportUsers() {
      exportEntity('user_list').then(outputExportResult);
    },

    sendInvites() {
      this.transitionTo('userInvited', Discourse.User.current());
    },

    deleteUser(user) {
      AdminUser.create(user).destroy({ deletePosts: true });
    }
  }

});
