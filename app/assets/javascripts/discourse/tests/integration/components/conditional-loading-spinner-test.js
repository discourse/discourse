import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | conditional-loading-spinner",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("condition is true", {
      template: hbs`
        {{#conditional-loading-spinner condition=true}}
        {{/conditional-loading-spinner}}
      `,

      async test(assert) {
        assert.ok(exists(".loading-container"));
        assert.ok(exists(".loading-container .spinner"));
      },
    });

    componentTest("condition is false", {
      template: hbs`
        {{#conditional-loading-spinner condition=false}}
          <b>test</b>
        {{/conditional-loading-spinner}}
      `,

      async test(assert) {
        assert.notOk(exists(".loading-container"));
        assert.deepEqual(query("b").innerText, "test");
      },
    });

    componentTest("size is small", {
      template: hbs`
        {{#conditional-loading-spinner condition=true size="small"}}
        {{/conditional-loading-spinner}}
      `,

      async test(assert) {
        assert.ok(exists(".loading-container.inline-spinner .spinner.small"));
      },
    });
  }
);
