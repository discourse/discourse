/**
  This view handles rendering of a user's avatar uploader

  @class PreferencesAvatarView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PreferencesAvatarView = Discourse.View.extend({
  templateName: "user/avatar",
  classNames: ["user-preferences"],

  selectedChanged: function() {
    var view = this;
    Em.run.next(function() {
      var value = view.get("controller.use_uploaded_avatar") ? "uploaded_avatar" : "gravatar";
      view.$('input:radio[name="avatar"]').val([value]);
    });
  }.observes('controller.use_uploaded_avatar')

});
