import { ajax } from 'discourse/lib/ajax';
import AdminUser from 'admin/models/admin-user';

const EmailLog = Discourse.Model.extend({});

EmailLog.reopenClass({

  create(attrs) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    return this._super(attrs);
  },

  findAll(filter, offset) {
    filter = filter || {};
    offset = offset || 0;

    const status = filter.status || "sent";
    filter = _.omit(filter, "status");

    return ajax(`/admin/email/${status}.json?offset=${offset}`, { data: filter })
                    .then(logs => _.map(logs, log => EmailLog.create(log)));
  }
});

export default EmailLog;
