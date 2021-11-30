import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | empty-state", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("it renders", {
    template: hbs`<EmptyState @title="title" @body="body" />`,

    test(assert) {
      assert.strictEqual(query("[data-test-title]").textContent, "title");
      assert.strictEqual(query("[data-test-body]").textContent, "body");
    },
  });
});
