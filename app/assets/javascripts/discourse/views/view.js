(function() {

  window.Discourse.View = Ember.View.extend(Discourse.Presence, {
    /* Overwrite this to do a different display
    */

    displayErrors: function(errors, callback) {
      alert(errors.join("\n"));
      return typeof callback === "function" ? callback() : void 0;
    }
  });

}).call(this);
