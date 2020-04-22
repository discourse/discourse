import Invite from "discourse/models/invite";

QUnit.module("model:invite");

QUnit.test("create", assert => {
  assert.ok(Invite.create(), "it can be created without arguments");
});
