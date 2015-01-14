moduleFor("controller:admin-site-settings");

test("filter", function() {
  var allSettings = [
    Ember.Object.create({
      nameKey: 'users', name: 'users',
      siteSettings: [Discourse.SiteSetting.create({"setting":"username_change_period","description":"x","default":3,"type":"fixnum","value":"3","category":"users"})]
    }),
    Ember.Object.create({
      nameKey: 'posting', name: 'posting',
      siteSettings: [Discourse.SiteSetting.create({"setting":"display_name_on_posts","description":"x","default":false,"type":"bool","value":"true","category":"posting"})]
    })
  ];

  var adminSiteSettingsController = this.subject({ model: allSettings });
  sinon.stub(adminSiteSettingsController, "transitionToRoute");

  adminSiteSettingsController.set('allSiteSettings', allSettings);
  equal(adminSiteSettingsController.get('content')[0].nameKey, 'users', "Can get first site setting category's name key.");

  adminSiteSettingsController.set('filter', 'username_change');
  equal(adminSiteSettingsController.get('content').length, 1, "Filter with one match for username_change");
  equal(adminSiteSettingsController.get('content')[0].nameKey, "all_results", "First element is all the results that match");
  equal(adminSiteSettingsController.get('content')[0].siteSettings[0].setting, "username_change_period", "Filter with one match for username_change");

  adminSiteSettingsController.setProperties({ filter: '', onlyOverridden: true });
  equal(adminSiteSettingsController.get('content').length, 1, "onlyOverridden with one match");
  equal(adminSiteSettingsController.get('content')[0].nameKey, "all_results", "onlyOverridden with one match");
  equal(adminSiteSettingsController.get('content')[0].siteSettings[0].setting, "display_name_on_posts", "onlyOverridden with one match");

});
