/**
  Data model for representing an export

  @class ExportCsv
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ExportCsv = Discourse.Model.extend({});

Discourse.ExportCsv.reopenClass({
  /**
    Exports user list

    @method export_user_list
  **/
  exportUserList: function() {
    return Discourse.ajax("/admin/export_csv/users.json").then(function(result) {
      if (result.success) {
        bootbox.alert(I18n.t("admin.export_csv.success"));
      } else {
        bootbox.alert(I18n.t("admin.export_csv.failed"));
      }
    });
  }
});
