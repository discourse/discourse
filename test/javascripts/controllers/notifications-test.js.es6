moduleFor('controller:notifications', 'controller:notifications', {
  needs: ['controller:header']
});

test("mixes in HasCurrentUser", function() {
  ok(Discourse.HasCurrentUser.detect(this.subject()));
});
