import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import pretender from "discourse/tests/helpers/create-pretender";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | site-header", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("first notification mask", {
    template: hbs`{{site-header}}`,

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

  componentTest("do not call authenticated endpoints as anonymous", {
    template: hbs`{{site-header}}`,
    anonymous: true,

    async test(assert) {
      assert.ok(
        queryAll(".ring-backdrop").length === 0,
        "there is no first notification mask for anonymous users"
      );

      pretender.get("/notifications", () => {
        assert.ok(false, "it should not try to refresh notifications");
        return [403, { "Content-Type": "application/json" }, {}];
      });

      // Click anywhere
      await click("header.d-header");
    },
  });
});
