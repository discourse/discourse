import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | group-membership-button", function (hooks) {
  setupRenderingTest(hooks);

  test("canJoinGroup", async function (assert) {
    this.set("model", { public_admission: false, is_group_user: true });

    await render(hbs`<GroupMembershipButton @model={{this.model}} />`);

    assert
      .dom(".group-index-join")
      .doesNotExist("can't join group if public_admission is false");

    this.set("model.public_admission", true);
    assert
      .dom(".group-index-join")
      .doesNotExist("can't join group if user is already in the group");

    this.set("model.is_group_user", false);
    assert.dom(".group-index-join").exists("allowed to join group");
  });

  test("canLeaveGroup", async function (assert) {
    this.set("model", { public_exit: false, is_group_user: false });

    await render(hbs`<GroupMembershipButton @model={{this.model}} />`);

    assert
      .dom(".group-index-leave")
      .doesNotExist("can't leave group if public_exit is false");

    this.set("model.public_exit", true);
    assert
      .dom(".group-index-leave")
      .doesNotExist("can't leave group if user is not in the group");

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

    assert
      .dom(".group-index-request")
      .doesNotExist(
        "can't request for membership if user is already in the group"
      );
    this.set("model.is_group_user", false);
    assert
      .dom(".group-index-request")
      .exists("allowed to request for group membership");
  });
});
