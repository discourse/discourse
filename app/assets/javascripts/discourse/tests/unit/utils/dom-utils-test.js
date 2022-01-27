import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import domUtils from "discourse-common/utils/dom-utils";

discourseModule("utils:dom-utils", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("offset", {
    template: hbs`{{d-button translatedLabel="baz"}}`,

    async test(assert) {
      const element = document.querySelector(".btn");
      const offset = domUtils.offset(element);
      const rect = element.getBoundingClientRect();

      assert.deepEqual(offset, {
        top: rect.top + window.scrollY,
        left: rect.left + window.scrollX,
      });
    },
  });

  componentTest("position", {
    template: hbs`{{d-button translatedLabel="baz"}}`,

    async test(assert) {
      const element = document.querySelector(".btn");
      const position = domUtils.position(element);

      assert.deepEqual(position, {
        top: element.offsetTop,
        left: element.offsetLeft,
      });
    },
  });
});
