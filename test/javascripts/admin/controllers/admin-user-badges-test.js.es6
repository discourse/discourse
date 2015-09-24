import Badge from 'discourse/models/badge';

moduleFor('controller:admin-user-badges', {
  needs: ['controller:adminUser']
});

test("grantableBadges", function() {
  const badgeFirst = Badge.create({id: 3, name: "A Badge", enabled: true});
  const badgeMiddle = Badge.create({id: 1, name: "My Badge", enabled: true});
  const badgeLast = Badge.create({id: 2, name: "Zoo Badge", enabled: true});
  const badgeDisabled = Badge.create({id: 4, name: "Disabled Badge", enabled: false});
  const controller = this.subject({ badges: [badgeLast, badgeFirst, badgeMiddle, badgeDisabled] });
  const sortedNames = [badgeFirst.name, badgeMiddle.name, badgeLast.name];
  const badgeNames = controller.get('grantableBadges').map(function(badge) {
    return badge.name;
  });


  not(badgeNames.contains(badgeDisabled), "excludes disabled badges");
  deepEqual(badgeNames, sortedNames, "sorts badges by name");
});
