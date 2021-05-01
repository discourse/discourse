import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | Widget | small-user-list",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("renders avatars and support for unknown", {
      template: hbs`{{mount-widget widget="small-user-list" args=args}}`,
      beforeEach() {
        this.set("args", {
          users: [
            { id: 456, username: "eviltrout" },
            { id: 457, username: "someone", unknown: true },
          ],
        });
      },
      async test(assert) {
        assert.ok(queryAll('[data-user-card="eviltrout"]').length === 1);
        assert.ok(queryAll('[data-user-card="someone"]').length === 0);
        assert.ok(queryAll(".unknown").length, "includes unkown user");
      },
    });
  }
);
