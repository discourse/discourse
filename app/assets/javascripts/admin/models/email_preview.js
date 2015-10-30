/**
  Our data model for showing a preview of an email

  @class EmailPreview
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.EmailPreview = Discourse.Model.extend({});

Discourse.EmailPreview.reopenClass({
  findDigest: function(lastSeenAt, username) {

    if (Em.isEmpty(lastSeenAt)) {
      lastSeenAt = moment().subtract(7, 'days').format('YYYY-MM-DD');
    }

    if (Em.isEmpty(username)) {
      username = Discourse.User.current().username;
    }

    return Discourse.ajax("/admin/email/preview-digest.json", {
      data: { last_seen_at: lastSeenAt, username: username }
    }).then(function (result) {
      return Discourse.EmailPreview.create(result);
    });
  }
});
