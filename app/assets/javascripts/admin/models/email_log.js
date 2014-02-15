/**
  Our data model for representing an email log.

  @class EmailLog
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.EmailLog = Discourse.Model.extend({});

Discourse.EmailLog.reopenClass({

  create: function(attrs) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = Discourse.AdminUser.create(attrs.user);
    }

    return this._super(attrs);
  },

  findAll: function(filter) {
    filter = filter || {};
    var status = filter.status || "all";
    filter = _.omit(filter, "status");

    return Discourse.ajax("/admin/email/" + status + ".json", { data: filter }).then(function(logs) {
      return _.map(logs, function (log) {
        return Discourse.EmailLog.create(log);
      });
    });
  }
});


