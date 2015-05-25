export default Discourse.Route.extend({

  beforeModel: function() {
    // HACK: Something with the way the user card intercepts clicks seems to break how the
    // transition into a user's activity works. This makes the back button work on mobile
    // where there is no user card as well as desktop where there is.
    if (Discourse.Mobile.mobileView) {
      this.replaceWith('userActivity');
    } else {
      this.transitionTo('userActivity');
    }
  }

});
