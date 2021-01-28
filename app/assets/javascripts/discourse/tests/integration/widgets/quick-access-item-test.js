import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";

const CONTENT_DIV_SELECTOR = "li > a > div";

discourseModule(
  "Integration | Component | Widget | quick-access-item",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("content attribute is escaped", {
      template: '{{mount-widget widget="quick-access-item" args=args}}',

      beforeEach() {
        this.set("args", { content: "<b>bold</b>" });
      },

      test(assert) {
        const contentDiv = queryAll(CONTENT_DIV_SELECTOR)[0];
        assert.equal(contentDiv.innerText, "<b>bold</b>");
      },
    });

    componentTest("escapedContent attribute is not escaped", {
      template: '{{mount-widget widget="quick-access-item" args=args}}',

      beforeEach() {
        this.set("args", { escapedContent: "&quot;quote&quot;" });
      },

      test(assert) {
        const contentDiv = queryAll(CONTENT_DIV_SELECTOR)[0];
        assert.equal(contentDiv.innerText, '"quote"');
      },
    });
  }
);
