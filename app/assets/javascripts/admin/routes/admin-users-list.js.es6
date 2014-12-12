export default Discourse.Route.extend({

  actions: {
    exportUsers: function() {
      Discourse.ExportCsv.exportUserList().then(function(result) {
        if (result.success) {
          bootbox.alert(I18n.t("admin.export_csv.success"));
        } else {
          bootbox.alert(I18n.t("admin.export_csv.failed"));
        }
      });
    },

    deleteUser: function(user) {
      Discourse.AdminUser.create(user).destroy({ deletePosts: true });
    }
  }

});
