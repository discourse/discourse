import { hbs } from "ember-cli-htmlbars";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";

discourseModule(
  "Integration | Component | site-setting | host-list",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("displays setting value", {
      template: hbs`{{site-setting setting=setting}}`,

      beforeEach() {
        this.set("setting", {
          setting: "blocked_onebox_domains",
          value: "a.com|b.com",
          type: "host_list",
        });
      },

      async test(assert) {
        assert.strictEqual(
          query(".formatted-selection").innerText,
          "a.com, b.com"
        );
      },
    });
  }
);
