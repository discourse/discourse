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

  didInsertElement: function() {
    this.set('loading', true);
    this.set('postLeft', null);
    this.set('postRight', null);

    var historyView = this;
    this.get('originalPost').loadVersions().then(function(result) {
      result.each(function(item) {
        item.description = "v" + item.number + " - " + Date.create(item.created_at).relative() + " - " +
          Em.String.i18n("changed_by", { author: item.display_username });
      });

      historyView.set('loading', false);
      historyView.set('versionLeft', result.first());
      historyView.set('versionRight', result.last());
      historyView.set('versions', result);
    });
  }
});


