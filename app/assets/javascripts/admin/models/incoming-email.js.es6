import { ajax } from "discourse/lib/ajax";
import AdminUser from "admin/models/admin-user";

const IncomingEmail = Discourse.Model.extend({});

IncomingEmail.reopenClass({
  create(attrs) {
    attrs = attrs || {};

    if (attrs.user) {
      attrs.user = AdminUser.create(attrs.user);
    }

    return this._super(attrs);
  },

  find(id) {
    return ajax(`/admin/email/incoming/${id}.json`);
  },

  findByBounced(id) {
    return ajax(`/admin/email/incoming_from_bounced/${id}.json`);
  },

  findAll(filter, offset) {
    filter = filter || {};
    offset = offset || 0;

    const status = filter.status || "received";
    filter = _.omit(filter, "status");

    return ajax(`/admin/email/${status}.json?offset=${offset}`, {
      data: filter
    }).then(incomings =>
      incomings.map(incoming => IncomingEmail.create(incoming))
    );
  },

  loadRawEmail(id) {
    return ajax(`/admin/email/incoming/${id}/raw.json`);
  }
});

export default IncomingEmail;
