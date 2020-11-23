import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";

discourseModule("Integration | Component | site-header", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("first notification mask", {
    template: `{{site-header}}`,

    beforeEach() {
      this.set("currentUser.unread_high_priority_notifications", 1);
      this.set("currentUser.read_first_notification", false);
    },

    async test(assert) {
      assert.ok(
        queryAll(".ring-backdrop").length === 1,
        "there is the first notification mask"
      );

      // Click anywhere
      await click("header.d-header");

      assert.ok(
        queryAll(".ring-backdrop").length === 0,
        "it hides the first notification mask"
      );
    },
  });
});
