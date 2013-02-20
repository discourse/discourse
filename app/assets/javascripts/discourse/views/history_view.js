(function() {

  window.Discourse.HistoryView = Ember.View.extend({
    templateName: 'history',
    title: 'History',
    modalClass: 'history-modal',
    loadSide: function(side) {
      var orig, version,
        _this = this;
      if (this.get("version" + side)) {
        orig = this.get('originalPost');
        version = this.get("version" + side + ".number");
        if (version === orig.get('version')) {
          return this.set("post" + side, orig);
        } else {
          return Discourse.Post.loadVersion(orig.get('id'), version, function(post) {
            return _this.set("post" + side, post);
          });
        }
      }
    },
    changedLeftVersion: (function() {
      return this.loadSide("Left");
    }).observes('versionLeft'),
    changedRightVersion: (function() {
      return this.loadSide("Right");
    }).observes('versionRight'),
    didInsertElement: function() {
      var _this = this;
      this.set('loading', true);
      this.set('postLeft', null);
      this.set('postRight', null);
      return this.get('originalPost').loadVersions(function(result) {
        _this.set('loading', false);
        _this.set('versionLeft', result.first());
        _this.set('versionRight', result.last());
        return _this.set('versions', result);
      });
    }
  });

}).call(this);
