import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | slow-mode-info", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("doesn't render if the topic is closed", {
    template: hbs`{{slow-mode-info topic=topic}}`,

    beforeEach() {
      this.set("topic", { slow_mode_seconds: 3600, closed: true });
    },

    test(assert) {
      assert.ok(!exists(".slow-mode-heading"), "it doesn't render the notice");
    },
  });

  componentTest("doesn't render if the slow mode is disabled", {
    template: hbs`{{slow-mode-info topic=topic}}`,

    beforeEach() {
      this.set("topic", { slow_mode_seconds: 0, closed: false });
    },

    test(assert) {
      assert.ok(!exists(".slow-mode-heading"), "it doesn't render the notice");
    },
  });

  componentTest("renders if slow mode is enabled", {
    template: hbs`{{slow-mode-info topic=topic}}`,

    beforeEach() {
      this.set("topic", { slow_mode_seconds: 3600, closed: false });
    },

    test(assert) {
      assert.equal(count(".slow-mode-heading"), 1);
    },
  });

  componentTest("staff and TL4 users can disable slow mode", {
    template: hbs`{{slow-mode-info topic=topic user=user}}`,

    beforeEach() {
      this.setProperties({
        topic: { slow_mode_seconds: 3600, closed: false },
        user: { canManageTopic: true },
      });
    },

    test(assert) {
      assert.equal(count(".slow-mode-remove"), 1);
    },
  });

  componentTest("regular users can't disable slow mode", {
    template: hbs`{{slow-mode-info topic=topic user=user}}`,

    beforeEach() {
      this.setProperties({
        topic: { slow_mode_seconds: 3600, closed: false },
        user: { canManageTopic: false },
      });
    },

    test(assert) {
      assert.ok(
        !exists(".slow-mode-remove"),
        "it doesn't let you disable slow mode"
      );
    },
  });
});
