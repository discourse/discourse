moduleFor('controller:notifications', 'controller:notifications', {
  needs: ['controller:header']
});

test("mixes in HasCurrentUser", function() {
  ok(Discourse.HasCurrentUser.detect(this.subject()));
});

test("by default uses NotificationController as its item controller", function() {
  equal(this.subject().get("itemController"), "notification");
});
