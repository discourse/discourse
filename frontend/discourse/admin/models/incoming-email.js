import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import AdminUser from "admin/models/admin-user";

export default class IncomingEmail extends EmberObject {
  static create(attrs) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    return super.create(attrs);
  }

  static find(id) {
    return ajax(`/admin/email-logs/incoming/${id}.json`);
  }

  static findByBounced(id) {
    return ajax(`/admin/email-logs/incoming_from_bounced/${id}.json`);
  }

  static findAll(filter, offset) {
    filter = filter || {};
    offset = offset || 0;

    const status = filter.status || "received";
    delete filter.status;

    return ajax(`/admin/email-logs/${status}.json?offset=${offset}`, {
      data: filter,
    }).then((incomings) =>
      incomings.map((incoming) => IncomingEmail.create(incoming))
    );
  }
}
