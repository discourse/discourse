moduleFor('controller:admin-user-badges', 'Admin User Badges Controller', {
  needs: ['controller:adminUser']
});

test("grantableBadges", function() {
  var badge_first = Discourse.Badge.create({id: 3, name: "A Badge"});
  var badge_middle = Discourse.Badge.create({id: 1, name: "My Badge"});
  var badge_last = Discourse.Badge.create({id: 2, name: "Zoo Badge"});
  var controller = this.subject({ badges: [badge_last, badge_first, badge_middle] });
  var sorted_names = [badge_first.name, badge_middle.name, badge_last.name];
  var badge_names = controller.get('grantableBadges').map(function(badge) {
    return badge.name;
  });

  deepEqual(badge_names, sorted_names, "sorts badges by name");
});
