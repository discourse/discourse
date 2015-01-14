import { outputExportResult } from 'discourse/lib/export-result';

export default Discourse.Route.extend({

  actions: {
    exportUsers: function() {
      Discourse.ExportCsv.exportUserList().then(outputExportResult);
    },

    deleteUser: function(user) {
      Discourse.AdminUser.create(user).destroy({ deletePosts: true });
    }
  }

});
