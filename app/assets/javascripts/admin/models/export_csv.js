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
    return Discourse.ajax("/admin/export_csv/export_entity.json", {data: {entity: 'user'}});
  },

  /**
    Exports staff action logs

    @method export_staff_action_logs
  **/
  exportStaffActionLogs: function() {
    return Discourse.ajax("/admin/export_csv/export_entity.json", {data: {entity: 'staff_action'}});
  },

  /**
    Exports screened email list

    @method export_screened_email_list
  **/
  exportScreenedEmailList: function() {
    return Discourse.ajax("/admin/export_csv/export_entity.json", {data: {entity: 'screened_email'}});
  },

  /**
    Exports screened IP list

    @method export_screened_ip_list
  **/
  exportScreenedIpList: function() {
    return Discourse.ajax("/admin/export_csv/export_entity.json", {data: {entity: 'screened_ip'}});
  },

  /**
    Exports screened URL list

    @method export_screened_url_list
  **/
  exportScreenedUrlList: function() {
    return Discourse.ajax("/admin/export_csv/export_entity.json", {data: {entity: 'screened_url'}});
  }
});
