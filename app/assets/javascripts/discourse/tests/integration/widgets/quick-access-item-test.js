import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

const CONTENT_DIV_SELECTOR = "li > a > div";

discourseModule(
  "Integration | Component | Widget | quick-access-item",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("content attribute is escaped", {
      template: hbs`{{mount-widget widget="quick-access-item" args=args}}`,

      beforeEach() {
        this.set("args", { content: "<b>bold</b>" });
      },

      test(assert) {
        const contentDiv = query(CONTENT_DIV_SELECTOR);
        assert.equal(contentDiv.innerText, "<b>bold</b>");
      },
    });

    componentTest("escapedContent attribute is not escaped", {
      template: hbs`{{mount-widget widget="quick-access-item" args=args}}`,

      beforeEach() {
        this.set("args", { escapedContent: "&quot;quote&quot;" });
      },

      test(assert) {
        const contentDiv = query(CONTENT_DIV_SELECTOR);
        assert.equal(contentDiv.innerText, '"quote"');
      },
    });
  }
);
