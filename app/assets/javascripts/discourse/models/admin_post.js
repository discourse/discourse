/**
  A data model for flagged/deleted posts.

  @class AdminPost
  @extends Discourse.Post
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminPost = Discourse.Post.extend({

  _attachCategory: function () {
    var categoryId = this.get("category_id");
    if (categoryId) {
      this.set("category", Discourse.Category.findById(categoryId));
    }
  }.on("init"),

  presentName: Em.computed.any('name', 'username'),

  sameUser: function() {
    return this.get("username") === Discourse.User.currentProp("username");
  }.property("username"),

  descriptionKey: function () {
    if (this.get("reply_to_post_number")) {
      return this.get("sameUser") ? "you_replied_to_post" : "user_replied_to_post";
    } else {
      return this.get("sameUser") ? "you_replied_to_topic" : "user_replied_to_topic";
    }
  }.property("reply_to_post_number", "sameUser"),

  descriptionHtml: function () {
    var descriptionKey = this.get("descriptionKey");
    if (!descriptionKey) { return; }

    var description = I18n.t("user_action." + descriptionKey, {
      userUrl: this.get("usernameUrl"),
      user: Handlebars.Utils.escapeExpression(this.get("presentName")),
      postUrl: this.get("url"),
      post_number: "#" + this.get("reply_to_post_number"),
      topicUrl: this.get("url"),
    });

    return new Handlebars.SafeString(description);

  }.property("descriptionKey")

});
