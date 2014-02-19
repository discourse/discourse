module("Discourse.AdminSiteSettingsController", {
  setup: function() {
    sinon.stub(Ember.run, "debounce").callsArg(1);
  },

  teardown: function() {
    Ember.run.debounce.restore();
  }
});

test("filter", function() {
  var allSettings = Em.A([Ember.Object.create({
    nameKey: 'users', name: 'users',
    siteSettings: [Discourse.SiteSetting.create({"setting":"username_change_period","description":"x","default":3,"type":"fixnum","value":"3","category":"users"})]
  }), Ember.Object.create({
    nameKey: 'posting', name: 'posting',
    siteSettings: [Discourse.SiteSetting.create({"setting":"display_name_on_posts","description":"x","default":false,"type":"bool","value":"true","category":"posting"})]
  })]);
  var adminSiteSettingsController = testController(Discourse.AdminSiteSettingsController, allSettings);
  adminSiteSettingsController.set('allSiteSettings', allSettings);

  equal(adminSiteSettingsController.get('content')[0].nameKey, 'users', "Can get first site setting category's name key.");

  adminSiteSettingsController.set('filter', 'username_change');
  equal(adminSiteSettingsController.get('content').length, 2, "a. Filter with one match for username_change");
  equal(adminSiteSettingsController.get('content')[0].nameKey, "all_results", "b. First element is all the results that match");
  equal(adminSiteSettingsController.get('content')[1].nameKey, "users", "c. Filter with one match for username_change");
  equal(adminSiteSettingsController.get('content')[1].siteSettings[0].setting, "username_change_period", "d. Filter with one match for username_change");

  adminSiteSettingsController.set('filter', 'name_on');
  equal(adminSiteSettingsController.get('content').length, 2, "a. Filter with one match for name_on");
  equal(adminSiteSettingsController.get('content')[1].nameKey, "posting", "b. Filter with one match for name_on");
  equal(adminSiteSettingsController.get('content')[1].siteSettings[0].setting, "display_name_on_posts", "c. Filter with one match for name_on");

  adminSiteSettingsController.set('filter', 'name');
  equal(adminSiteSettingsController.get('content').length, 3, "a. Filter with one match for name");
  equal(adminSiteSettingsController.get('content')[0].nameKey, "all_results", "b. First element is all the results that match");
  equal(adminSiteSettingsController.get('content')[1].nameKey, "users", "c. Filter with one match for name");
  equal(adminSiteSettingsController.get('content')[2].nameKey, "posting", "d. Filter with one match for name");
  equal(adminSiteSettingsController.get('content')[1].siteSettings[0].setting, "username_change_period", "e. Filter with one match for name");
  equal(adminSiteSettingsController.get('content')[2].siteSettings[0].setting, "display_name_on_posts", "f. Filter with one match for name");

  adminSiteSettingsController.set('filter', '');
  adminSiteSettingsController.set('onlyOverridden', true);
  equal(adminSiteSettingsController.get('content').length, 2, "a. onlyOverridden with one match");
  equal(adminSiteSettingsController.get('content')[1].nameKey, "posting", "b. onlyOverridden with one match");
  equal(adminSiteSettingsController.get('content')[1].siteSettings[0].setting, "display_name_on_posts", "c. onlyOverridden with one match");

});
