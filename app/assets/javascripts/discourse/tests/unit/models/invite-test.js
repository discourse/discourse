import { module, test } from "qunit";
import Invite from "discourse/models/invite";

module("Unit | Model | invite", function () {
  test("create", function (assert) {
    assert.ok(Invite.create(), "it can be created without arguments");
  });
});
