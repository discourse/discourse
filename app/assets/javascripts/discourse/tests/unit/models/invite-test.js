import { test, module } from "qunit";
import Invite from "discourse/models/invite";

module("model:invite");

test("create", (assert) => {
  assert.ok(Invite.create(), "it can be created without arguments");
});
