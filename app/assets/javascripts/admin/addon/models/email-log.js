import AdminUser from "admin/models/admin-user";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse-common/lib/get-url";

class EmailLog extends EmberObject {}

EmailLog.reopenClass({
  create(attrs) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    if (attrs.post_url) {
      attrs.post_url = getURL(attrs.post_url);
    }

    return this._super(attrs);
  },

  findAll(filter, offset) {
    filter = filter || {};
    offset = offset || 0;

    const status = filter.status || "sent";
    delete filter.status;

    return ajax(`/admin/email/${status}.json?offset=${offset}`, {
      data: filter,
    }).then((logs) => logs.map((log) => EmailLog.create(log)));
  },
});

export default EmailLog;
