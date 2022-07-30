import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | group-membership-button", function (hooks) {
  setupRenderingTest(hooks);

  test("canJoinGroup", async function (assert) {
    this.set("model", { public_admission: false, is_group_user: true });

    await render(hbs`<GroupMembershipButton @model={{this.model}} />`);

    assert.ok(
      !exists(".group-index-join"),
      "can't join group if public_admission is false"
    );

    this.set("model.public_admission", true);
    assert.ok(
      !exists(".group-index-join"),
      "can't join group if user is already in the group"
    );

    this.set("model.is_group_user", false);
    assert.ok(exists(".group-index-join"), "allowed to join group");
  });

  test("canLeaveGroup", async function (assert) {
    this.set("model", { public_exit: false, is_group_user: false });

    await render(hbs`<GroupMembershipButton @model={{this.model}} />`);

    assert.ok(
      !exists(".group-index-leave"),
      "can't leave group if public_exit is false"
    );

    this.set("model.public_exit", true);
    assert.ok(
      !exists(".group-index-leave"),
      "can't leave group if user is not in the group"
    );

    this.set("model.is_group_user", true);
    assert.strictEqual(
      count(".group-index-leave"),
      1,
      "allowed to leave group"
    );
  });

  test("canRequestMembership", async function (assert) {
    this.set("model", {
      allow_membership_requests: true,
      is_group_user: true,
    });

    await render(hbs`<GroupMembershipButton @model={{this.model}} />`);

    assert.ok(
      !exists(".group-index-request"),
      "can't request for membership if user is already in the group"
    );
    this.set("model.is_group_user", false);
    assert.ok(
      exists(".group-index-request"),
      "allowed to request for group membership"
    );
  });
});
