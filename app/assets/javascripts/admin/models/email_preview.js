/**
  Our data model for showing a preview of an email

  @class EmailPreview
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.EmailPreview = Discourse.Model.extend({});

Discourse.EmailPreview.reopenClass({
  findDigest: function(last_seen_at) {
    return $.ajax("/admin/email/preview-digest.json", {
      data: {last_seen_at: last_seen_at}
    }).then(function (result) {
      return Discourse.EmailPreview.create(result);
    });
  }
});


