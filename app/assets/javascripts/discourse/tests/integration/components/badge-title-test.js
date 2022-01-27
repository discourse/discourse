import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import EmberObject from "@ember/object";
import { click } from "@ember/test-helpers";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";

discourseModule("Integration | Component | badge-title", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("badge title", {
    template: hbs`
      {{badge-title selectableUserBadges=selectableUserBadges}}
    `,

    beforeEach() {
      this.set("subject", selectKit());
      this.set("selectableUserBadges", [
        EmberObject.create({
          id: 0,
          badge: { name: "(none)" },
        }),
        EmberObject.create({
          id: 42,
          badge_id: 102,
          badge: { name: "Test" },
        }),
      ]);
    },

    async test(assert) {
      pretender.put("/u/eviltrout/preferences/badge_title", () => [
        200,
        { "Content-Type": "application/json" },
        {},
      ]);
      await this.subject.expand();
      await this.subject.selectRowByValue(42);
      await click(".btn");
      assert.strictEqual(this.currentUser.title, "Test");
    },
  });
});
