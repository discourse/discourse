/*jshint newcap:false*/
/*global diff_match_patch:true assetPath:true*/

/**
  This view handles rendering of the history of a post

  @class HistoryView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.HistoryView = Discourse.View.extend({
  templateName: 'history',
  title: Em.String.i18n('history'),
  modalClass: 'history-modal',
  diffLibraryLoaded: false,
  diff: null,

  init: function(){
    this._super();
    var historyView = this;
    $LAB.script(assetPath('defer/google_diff_match_patch')).wait(function(){
      historyView.set('diffLibraryLoaded', true);
    });
  },

  loadSide: function(side) {
    if (this.get("version" + side)) {
      var orig = this.get('originalPost');
      var version = this.get("version" + side + ".number");
      if (version === orig.get('version')) {
        this.set("post" + side, orig);
      } else {
        var historyView = this;
        Discourse.Post.loadVersion(orig.get('id'), version).then(function(post) {
          historyView.set("post" + side, post);
        });
      }
    }
  },

  changedLeftVersion: function() {
    this.loadSide("Left");
  }.observes('versionLeft'),

  changedRightVersion: function() {
    this.loadSide("Right");
  }.observes('versionRight'),

  loadedPosts: function() {
    if (this.get('diffLibraryLoaded') && this.get('postLeft') && this.get('postRight')) {
      var dmp = new diff_match_patch(),
          before = this.get("postLeft.cooked"),
          after = this.get("postRight.cooked"),
          diff = dmp.diff_main(before, after);
      dmp.diff_cleanupSemantic(diff);
      this.set('diff', dmp.diff_prettyHtml(diff));
    }
  }.observes('diffLibraryLoaded', 'postLeft', 'postRight'),

  didInsertElement: function() {
    this.setProperties({
      loading: true,
      postLeft: null,
      postRight: null
    });

    var historyView = this;
    this.get('originalPost').loadVersions().then(function(result) {
      result.each(function(item) {
        item.description = "v" + item.number + " - " + Date.create(item.created_at).relative() + " - " +
          Em.String.i18n("changed_by", { author: item.display_username });
      });

      historyView.setProperties({
        loading: false,
        versionLeft: result.first(),
        versionRight: result.last(),
        versions: result
      });
    });
  }
});
