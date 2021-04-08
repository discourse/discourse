// https://github.com/jmurphyau/ember-truth-helpers/blob/master/tests/unit/helpers/not-test.js
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Unit | Helper | not", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("simple test 1", {
    template: hbs`<div id="not-test">[{{not true}}] [{{not false}}] [{{not null}}] [{{not undefined}}] [{{not ''}}] [{{not ' '}}]</div>`,

    test(assert) {
      assert.equal(
        query("#not-test").textContent,
        "[false] [true] [true] [true] [true] [false]",
        'value should be "[false] [true] [true] [true] [true] [false]"'
      );
    },
  });

  componentTest("simple test 2", {
    template: hbs`<div id="not-test">[{{not true false}}] [{{not true false}}] [{{not null null false null}}] [{{not false null ' ' true}}]</div>`,

    test(assert) {
      assert.equal(
        query("#not-test").textContent,
        "[false] [false] [true] [false]",
        'value should be "[false] [false] [true] [false]"'
      );
    },
  });
});
