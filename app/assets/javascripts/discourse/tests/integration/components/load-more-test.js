import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { configureEyeline } from "discourse/lib/eyeline";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | load-more", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("updates once after initialization", {
    template: hbs`
      {{#load-more selector=".numbers tr" action=loadMore}}
        <table class="numbers"><tr></tr></table>
      {{/load-more}}
    `,

    beforeEach() {
      this.set("loadMore", () => this.set("loadedMore", true));
      configureEyeline({
        skipUpdate: false,
        rootElement: "#ember-testing",
      });
    },

    afterEach() {
      configureEyeline();
    },

    test(assert) {
      assert.ok(this.loadedMore);
    },
  });
});
