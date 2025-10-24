import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import GroupMembershipButton from "discourse/components/group-membership-button";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | group-membership-button", function (hooks) {
  setupRenderingTest(hooks);

  test("canJoinGroup", async function (assert) {
    const self = this;

    this.set("model", { public_admission: false, is_group_user: true });

    await render(
      <template><GroupMembershipButton @model={{self.model}} /></template>
    );

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
    const self = this;

    this.set("model", { public_exit: false, is_group_user: false });

    await render(
      <template><GroupMembershipButton @model={{self.model}} /></template>
    );

    assert
      .dom(".group-index-leave")
      .doesNotExist("can't leave group if public_exit is false");

    this.set("model.public_exit", true);
    assert
      .dom(".group-index-leave")
      .doesNotExist("can't leave group if user is not in the group");

    this.set("model.is_group_user", true);
    assert.dom(".group-index-leave").exists("allowed to leave group");
  });

  test("canRequestMembership", async function (assert) {
    const self = this;

    this.set("model", {
      allow_membership_requests: true,
      is_group_user: true,
    });

    await render(
      <template><GroupMembershipButton @model={{self.model}} /></template>
    );

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
