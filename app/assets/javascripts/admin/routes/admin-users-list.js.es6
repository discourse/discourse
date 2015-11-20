import { exportEntity } from 'discourse/lib/export-csv';
import { outputExportResult } from 'discourse/lib/export-result';

export default Discourse.Route.extend({

  actions: {
    exportUsers: function() {
      exportEntity('user_list').then(outputExportResult);
    },

    sendInvites: function() {
      this.transitionTo('userInvited', Discourse.User.current());
    },

    deleteUser: function(user) {
      Discourse.AdminUser.create(user).destroy({ deletePosts: true });
    }
  }

});
