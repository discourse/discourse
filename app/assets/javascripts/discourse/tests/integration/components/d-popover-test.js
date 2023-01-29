import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import {
  hidePopover,
  isPopoverShown,
  showPopover,
} from "discourse/lib/d-popover";

module("Integration | Component | d-popover", function (hooks) {
  setupRenderingTest(hooks);

  test("show/hide popover from lib", async function (assert) {
    let showCallCount = 0;
    let hideCallCount = 0;

    this.set("onButtonClick", (_, event) => {
      if (isPopoverShown(event)) {
        hidePopover(event);
        hideCallCount++;
      } else {
        // Note: we need to override the default `trigger` and `hideOnClick`
        // settings in order to completely control showing / hiding the tip
        // via showPopover / hidePopover. Otherwise tippy's event listeners
        // will compete with those created in this test (on DButton).
        showPopover(event, {
          content: "test",
          duration: 0,
          trigger: "manual",
          hideOnClick: false,
        });
        showCallCount++;
      }
    });

    await render(hbs`
      <DButton
        @translatedLabel="test"
        @action={{this.onButtonClick}}
        @forwardEvent={{true}}
      />
    `);

    assert.notOk(document.querySelector("div[data-tippy-root]"));

    await click(".btn");
    assert.strictEqual(
      document.querySelector("div[data-tippy-root]").innerText.trim(),
      "test"
    );

    await click(".btn");

    assert.notOk(document.querySelector("div[data-tippy-root]"));

    assert.strictEqual(showCallCount, 1, "showPopover was invoked once");
    assert.strictEqual(hideCallCount, 1, "hidePopover was invoked once");
  });

  test("show/hide popover from component", async function (assert) {
    await render(hbs`
      <DPopover>
        <DButton class="trigger" @icon="chevron-down" />
        <ul>
          <li class="test">foo</li>
          <li><DButton class="closer" @icon="times" /></li>
        </ul>
      </DPopover>
    `);

    assert.notOk(exists(".d-popover.is-expanded"));
    assert.notOk(exists(".test"));

    await click(".trigger");

    assert.ok(exists(".d-popover.is-expanded"));
    assert.strictEqual(query(".test").innerText.trim(), "foo");

    await click(".closer");
    assert.notOk(exists(".d-popover.is-expanded"));
  });

  test("using options with component", async function (assert) {
    await render(hbs`
      <DPopover @options={{hash content="bar"}}>
        <DButton @icon="chevron-down" />
      </DPopover>
    `);

    await click(".btn");
    assert.strictEqual(query(".tippy-content").innerText.trim(), "bar");
  });

  test("d-popover component accepts a block", async function (assert) {
    await render(hbs`
      <DPopover as |state|>
        <DButton @icon={{if state.isExpanded "chevron-up" "chevron-down"}} />
      </DPopover>
    `);

    assert.ok(exists(".d-icon-chevron-down"));

    await click(".btn");
    assert.ok(exists(".d-icon-chevron-up"));
  });

  test("d-popover component accepts a class property", async function (assert) {
    await render(hbs`<DPopover @class="foo"></DPopover>`);

    assert.ok(exists(".d-popover.foo"));
  });

  test("d-popover component closes on escape key", async function (assert) {
    await render(hbs`
      <DPopover as |state|>
        <DButton @icon={{if state.isExpanded "chevron-up" "chevron-down"}} />
      </DPopover>
    `);

    await click(".btn");
    assert.ok(exists(".d-popover.is-expanded"));

    await triggerKeyEvent(document, "keydown", "Escape");
    assert.notOk(exists(".d-popover.is-expanded"));
  });
});
