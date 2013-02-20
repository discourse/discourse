(function() {

  window.Discourse.ExcerptPostView = Ember.View.extend({
    mute: function() {
      return this.update(true);
    },
    unmute: function() {
      return this.update(false);
    },
    refreshLater: Discourse.debounce((function() {
      return this.get('controller.controllers.listController').refresh();
    }), 1000),
    update: function(v) {
      var _this = this;
      this.set('muted', v);
      return jQuery.post("/t/" + this.topic_id + "/" + (v ? "mute" : "unmute"), {
        _method: 'put',
        success: function() {
          /* I experimented with this, but if feels like whackamole
          */

          /* @refreshLater()
          */

        }
      });
    }
  });

}).call(this);
