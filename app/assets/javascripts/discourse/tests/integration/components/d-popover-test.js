import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { showPopover } from "discourse/lib/d-popover";
import { click } from "@ember/test-helpers";

discourseModule("Integration | Component | d-popover", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("show/hide popover from lib", {
    template: hbs`{{d-button translatedLabel="test" action=onButtonClick forwardEvent=true}}`,

    beforeEach() {
      this.set("onButtonClick", (_, event) => {
        showPopover(event, { content: "test", trigger: "click", duration: 0 });
      });
    },

    async test(assert) {
      assert.notOk(document.querySelector("div[data-tippy-root]"));

      await click(".btn");

      assert.equal(
        document.querySelector("div[data-tippy-root]").innerText.trim(),
        "test"
      );

      await click(".btn");

      assert.notOk(document.querySelector("div[data-tippy-root]"));
    },
  });

  componentTest("show/hide popover from component", {
    template: hbs`{{#d-popover}}{{d-button icon="chevron-down"}}<ul><li class="test">foo</li></ul>{{/d-popover}}`,

    async test(assert) {
      assert.notOk(exists(".d-popover.is-expanded"));
      assert.notOk(exists(".test"));

      await click(".btn");

      assert.ok(exists(".d-popover.is-expanded"));
      assert.equal(query(".test").innerText.trim(), "foo");
    },
  });

  componentTest("using options with component", {
    template: hbs`{{#d-popover options=(hash content="bar")}}{{d-button icon="chevron-down"}}{{/d-popover}}`,

    async test(assert) {
      await click(".btn");

      assert.equal(query(".tippy-content").innerText.trim(), "bar");
    },
  });

  componentTest("d-popover component accepts a block", {
    template: hbs`{{#d-popover as |state|}}{{d-button icon=(if state.isExpanded "chevron-up" "chevron-down")}}{{/d-popover}}`,

    async test(assert) {
      assert.ok(exists(".d-icon-chevron-down"));

      await click(".btn");

      assert.ok(exists(".d-icon-chevron-up"));
    },
  });
});
