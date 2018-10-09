(function() {
  const authenticationData = JSON.parse(
    document.getElementById("data-authentication").dataset.authenticationData
  );

  Discourse.showingSignup = true;
  require("discourse/routes/application").default.reopen({
    actions: {
      didTransition: function() {
        Em.run.next(function() {
          Discourse.authenticationComplete(authenticationData);
        });
        return this._super();
      }
    }
  });
})();
