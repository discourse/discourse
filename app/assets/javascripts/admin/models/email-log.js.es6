import AdminUser from 'admin/models/admin-user';

const EmailLog = Discourse.Model.extend({});

EmailLog.reopenClass({

  create: function(attrs) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    return this._super(attrs);
  },

  findAll: function(filter) {
    filter = filter || {};
    var status = filter.status || "all";
    filter = _.omit(filter, "status");

    return Discourse.ajax("/admin/email/" + status + ".json", { data: filter }).then(function(logs) {
      return _.map(logs, function (log) {
        return EmailLog.create(log);
      });
    });
  }
});

export default EmailLog;
