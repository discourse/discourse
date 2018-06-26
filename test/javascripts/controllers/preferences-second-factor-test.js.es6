moduleFor("controller:preferences/second-factor");

QUnit.test(
  "displayOAuthWarning when OAuth login methods are disabled",
  function(assert) {
    const controller = this.subject({
      siteSettings: {
        enable_google_oauth2_logins: false
      }
    });

    assert.equal(controller.get("displayOAuthWarning"), false);
  }
);

QUnit.test("displayOAuthWarning when OAuth login methods are enabled", function(
  assert
) {
  const controller = this.subject({
    siteSettings: {
      enable_google_oauth2_logins: true
    }
  });

  assert.equal(controller.get("displayOAuthWarning"), true);
});
