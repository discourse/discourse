/**
  Our data model for showing a preview of an email

  @class EmailPreview
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.EmailPreview = Discourse.Model.extend({});

Discourse.EmailPreview.reopenClass({
  findDigest: function(lastSeenAt) {

    if (Em.isEmpty(lastSeenAt)) {
      lastSeenAt = moment().subtract('days',7).format('YYYY-MM-DD');
    }

    return Discourse.ajax("/admin/email/preview-digest.json", {
      data: {last_seen_at: lastSeenAt}
    }).then(function (result) {
      return Discourse.EmailPreview.create(result);
    });
  }
});


