(function() {

  /**
    Our data model for representing an email log.

    @class EmailLog    
    @extends Discourse.Model
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.EmailLog = Discourse.Model.extend({});

  window.Discourse.EmailLog.reopenClass({

    create: function(attrs) {
      if (attrs.user) {
        attrs.user = Discourse.AdminUser.create(attrs.user);
      }
      return this._super(attrs);
    },

    findAll: function(filter) {
      var result;
      result = Em.A();
      jQuery.ajax({
        url: "/admin/email_logs.json",
        data: { filter: filter },
        success: function(logs) {
          logs.each(function(log) {
            result.pushObject(Discourse.EmailLog.create(log));
          });
        }
      });
      return result;
    }
  });

}).call(this);
