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
    return Discourse.ajax("/admin/export_csv/users.json");
  },

  /**
    Exports screened IPs list

    @method export_screened_ips_list
  **/
  exportScreenedIpsList: function() {
    return Discourse.ajax("/admin/export_csv/screened_ips.json");
  }
});
