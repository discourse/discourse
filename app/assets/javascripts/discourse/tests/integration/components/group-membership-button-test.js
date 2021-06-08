import {
  count,
  discourseModule,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | group-membership-button",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("canJoinGroup", {
      template: hbs`{{group-membership-button model=model}}`,

      beforeEach() {
        this.set("model", { public_admission: false, is_group_user: true });
      },

      async test(assert) {
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
      },
    });

    componentTest("canLeaveGroup", {
      template: hbs`{{group-membership-button model=model}}`,
      beforeEach() {
        this.set("model", { public_exit: false, is_group_user: false });
      },
      async test(assert) {
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
        assert.equal(count(".group-index-leave"), 1, "allowed to leave group");
      },
    });

    componentTest("canRequestMembership", {
      template: hbs`{{group-membership-button model=model}}`,
      beforeEach() {
        this.set("model", {
          allow_membership_requests: true,
          is_group_user: true,
        });
      },

      async test(assert) {
        assert.ok(
          !exists(".group-index-request"),
          "can't request for membership if user is already in the group"
        );
        this.set("model.is_group_user", false);
        assert.ok(
          exists(".group-index-request"),
          "allowed to request for group membership"
        );
      },
    });
  }
);
