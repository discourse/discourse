import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import AdminUser from "admin/models/admin-user";

export default class EmailLog extends EmberObject {
  static create(attrs) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    if (attrs.post_url) {
      attrs.post_url = getURL(attrs.post_url);
    }

    return super.create(attrs);
  }

  static findAll(filter, offset) {
    filter = filter || {};
    offset = offset || 0;

    const status = filter.status || "sent";
    delete filter.status;

    return ajax(`/admin/email/${status}.json?offset=${offset}`, {
      data: filter,
    }).then((logs) => logs.map((log) => EmailLog.create(log)));
  }
}
