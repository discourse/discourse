/*jshint newcap:false*/
/*global diff_match_patch:true assetPath:true*/

/**
  This controller handles displaying of history

  @class HistoryController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.HistoryController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {
  diffLibraryLoaded: false,
  diff: null,

  init: function(){
    this._super();
    var historyController = this;
    $LAB.script(assetPath('defer/google_diff_match_patch')).wait(function(){
      historyController.set('diffLibraryLoaded', true);
    });
  },

  loadSide: function(side) {
    if (this.get("version" + side)) {
      var orig = this.get('model');
      var version = this.get("version" + side + ".number");
      if (version === orig.get('version')) {
        this.set("post" + side, orig);
      } else {
        var historyController = this;
        Discourse.Post.loadVersion(orig.get('id'), version).then(function(post) {
          historyController.set("post" + side, post);
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

  refresh: function() {
    this.setProperties({
      loading: true,
      postLeft: null,
      postRight: null
    });

    var historyController = this;
    this.get('model').loadVersions().then(function(result) {
      _.each(result,function(item) {

        var age = Discourse.Formatter.relativeAge(new Date(item.created_at), {
          format: 'medium',
          leaveAgo: true,
          wrapInSpan: false});

        item.description = "v" + item.number + " - " + age + " - " + I18n.t("changed_by", { author: item.display_username });
      });

      historyController.setProperties({
        loading: false,
        versionLeft: result[0],
        versionRight: result[result.length-1],
        versions: result
      });
    });
  }

});


