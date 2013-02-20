(function() {

  Discourse.ShareController = Ember.Controller.extend({
    /* When the user clicks the post number, we pop up a share box
    */

    shareLink: function(e, url) {
      var x;
      x = e.pageX - 150;
      if (x < 25) {
        x = 25;
      }
      jQuery('#share-link').css({
        left: "" + x + "px",
        top: "" + (e.pageY - 100) + "px"
      });
      this.set('link', url);
      return false;
    },
    /* Close the share controller
    */

    close: function() {
      this.set('link', '');
      return false;
    }
  });

}).call(this);
