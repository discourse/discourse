/**
  This controller handles displaying of history

  @class HistoryController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.HistoryController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {
  loading: false,
  viewMode: "side_by_side",

  refresh: function(postId, postVersion) {
    this.setProperties({
      loading: true,
      viewMode: Discourse.Mobile.mobileView ? "inline" : "side_by_side"
    });

    var self = this;
    Discourse.Post.loadRevision(postId, postVersion).then(function (result) {
      self.setProperties({
        loading: false,
        model: result
      });
    });
  },

  createdAtDate: function() { return moment(this.get("created_at")).format("LLLL"); }.property("created_at"),

  previousVersionNumber: function() { return this.get("version") - 1; }.property("version"),
  currentVersionNumber: Em.computed.alias("version"),

  isFirstVersion: Em.computed.equal("version", 2),
  isLastVersion: Discourse.computed.propertyEqual("version", "revisions_count"),

  displayingInline: Em.computed.equal("viewMode", "inline"),
  displayingSideBySide: Em.computed.equal("viewMode", "side_by_side"),
  displayingSideBySideMarkdown: Em.computed.equal("viewMode", "side_by_side_markdown"),

  diff: function() { return this.get(this.get("viewMode")); }.property("inline", "side_by_side", "side_by_side_markdown", "viewMode"),

  actions: {
    loadFirstVersion: function() { this.refresh(this.get("post_id"), 2); },
    loadPreviousVersion: function() { this.refresh(this.get("post_id"), this.get("version") - 1); },
    loadNextVersion: function() { this.refresh(this.get("post_id"), this.get("version") + 1); },
    loadLastVersion: function() { this.refresh(this.get("post_id"), this.get("revisions_count")); },

    displayInline: function() { this.set("viewMode", "inline"); },
    displaySideBySide: function() { this.set("viewMode", "side_by_side"); },
    displaySideBySideMarkdown: function() { this.set("viewMode", "side_by_side_markdown"); }
  }
});
