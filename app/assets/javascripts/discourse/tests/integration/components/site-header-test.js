import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import pretender from "discourse/tests/helpers/create-pretender";
import hbs from "htmlbars-inline-precompile";
import { click } from "@ember/test-helpers";

discourseModule("Integration | Component | site-header", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser.set("unread_high_priority_notifications", 1);
    this.currentUser.set("read_first_notification", false);
  });

  componentTest("first notification mask", {
    template: hbs`{{site-header}}`,

    async test(assert) {
      assert.strictEqual(
        count(".ring-backdrop"),
        1,
        "there is the first notification mask"
      );

      // Click anywhere
      await click("header.d-header");

      assert.ok(
        !exists(".ring-backdrop"),
        "it hides the first notification mask"
      );
    },
  });

  componentTest("do not call authenticated endpoints as anonymous", {
    template: hbs`{{site-header}}`,
    anonymous: true,

    async test(assert) {
      assert.ok(
        !exists(".ring-backdrop"),
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
