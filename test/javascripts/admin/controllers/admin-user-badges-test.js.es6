import Badge from 'discourse/models/badge';

moduleFor('controller:admin-user-badges', {
  needs: ['controller:adminUser']
});

test("grantableBadges", function() {
  const badgeFirst = Badge.create({id: 3, name: "A Badge"});
  const badgeMiddle = Badge.create({id: 1, name: "My Badge"});
  const badgeLast = Badge.create({id: 2, name: "Zoo Badge"});
  const controller = this.subject({ badges: [badgeLast, badgeFirst, badgeMiddle] });
  const sortedNames = [badgeFirst.name, badgeMiddle.name, badgeLast.name];
  const badgeNames = controller.get('grantableBadges').map(function(badge) {
    return badge.name;
  });

  deepEqual(badgeNames, sortedNames, "sorts badges by name");
});
