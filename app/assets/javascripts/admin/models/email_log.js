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
    var result = Em.A();
    Discourse.ajax("/admin/email/logs.json", {
      data: { filter: filter }
    }).then(function(logs) {
      _.each(logs,function(log) {
        result.pushObject(Discourse.EmailLog.create(log));
      });
    });
    return result;
  }
});


