import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';
import AdminUser from 'admin/models/admin-user';

export default Discourse.Route.extend({

  actions: {
    exportUsers: function() {
      exportEntity('user_list').then(outputExportResult);
    },

    sendInvites: function() {
      this.transitionTo('userInvited', Discourse.User.current());
    },

    deleteUser: function(user) {
      AdminUser.create(user).destroy({ deletePosts: true });
    }
  }

});
