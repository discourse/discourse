import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Toolbar from "discourse/static/dev-tools/toolbar";
import { CORE_TOOLS } from "discourse/static/dev-tools/tools";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/**
 * The toolbar as it is meant to read, left to right.
 *
 * Spelled out rather than derived from the tool table, so that the two
 * assertions below can disagree. One holds the rendered toolbar to this order;
 * the other holds the table to it. Deriving the expectation from the table
 * would let both move together and catch neither the toolbar rendering
 * something other than the table nor the table itself being reordered.
 */
const EXPECTED_ORDER = [
  "gripper",
  "plugin-outlet-debug",
  "block-debug",
  "upcoming-changes-debug",
  "safe-mode",
  "verbose-localization",
  "a11y",
  "disable-dev-tools",
];

/** What each landmark renders as, by the identifier it is listed under. */
const SELECTORS = {
  gripper: ".gripper",
  "plugin-outlet-debug": ".toggle-plugin-outlets",
  "block-debug": ".toggle-blocks",
  "upcoming-changes-debug": ".toggle-upcoming-changes-menu",
  "safe-mode": ".toggle-safe-mode",
  "verbose-localization": ".toggle-verbose-localization",
  a11y: ".toggle-a11y",
  "disable-dev-tools": ".disable-dev-tools",
};

/**
 * The order the toolbar's landmarks appear in, read back from the rendered DOM.
 *
 * Matches against descendants rather than direct children so that a tool free
 * to wrap its button, as the ones built on a menu do, is still found. Repeats
 * are reported rather than collapsed, so a landmark rendered twice fails the
 * comparison instead of reading back as one.
 */
function renderedOrder() {
  const seen = [];

  for (const element of document.querySelectorAll(".dev-tools-toolbar *")) {
    for (const [id, selector] of Object.entries(SELECTORS)) {
      if (element.matches(selector)) {
        seen.push(id);
      }
    }
  }

  return seen;
}

module("Integration | Component | dev-tools | toolbar", function (hooks) {
  setupRenderingTest(hooks);

  test("renders every tool, in order, between the gripper and the disable button", async function (assert) {
    await render(<template><Toolbar /></template>);

    assert.deepEqual(
      renderedOrder(),
      EXPECTED_ORDER,
      "each tool mounts its button, in the order the table lists it"
    );
  });

  test("the tool table is what the toolbar renders", async function (assert) {
    assert.deepEqual(
      CORE_TOOLS.map(({ id }) => id),
      EXPECTED_ORDER.slice(1, -1),
      "the table lists exactly the tools the toolbar is expected to show, in that order"
    );
  });

  test("the gripper and disable button render outside the tool list", async function (assert) {
    await render(<template><Toolbar /></template>);

    assert
      .dom(".dev-tools-toolbar > .gripper")
      .exists("the gripper is a child of the toolbar, not of a tool");
    assert
      .dom(".dev-tools-toolbar > .disable-dev-tools")
      .exists("the disable button is a child of the toolbar, not of a tool");
  });
});
