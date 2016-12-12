import { currentUser } from "helpers/qunit-helpers";

moduleFor("controller:group-index");

test("canJoinGroup", function() {
  this.subject().setProperties({
    model: { public: false }
  });

  this.subject().set("currentUser", currentUser());

  equal(this.subject().get("canJoinGroup"), false, "non public group cannot be joined");

  this.subject().set("model.public", true);

  equal(this.subject().get("canJoinGroup"), true, "public group can be joined");

  this.subject().setProperties({ currentUser: null, model: { public: true } });

  equal(this.subject().get("canJoinGroup"), false, "can't join group when not logged in");
});

test('canRequestMembership', function() {
  this.subject().setProperties({
    model: { allow_membership_requests: false, alias_level: 0 }
  })

  equal(this.subject().get('canRequestMembership'), false);

  this.subject().setProperties({
    currentUser: currentUser(), model: { allow_membership_requests: true, alias_level: 99 }
  });

  equal(this.subject().get('canRequestMembership'), true);

  this.subject().set("model.alias_level", 0);

  equal(this.subject().get('canRequestMembership'), false);
});
