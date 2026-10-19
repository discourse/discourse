import { find, render, triggerEvent } from "@ember/test-helpers";
import "discourse/static/dev-tools/styles.css";
import { module, test } from "qunit";
import Toolbar from "discourse/static/dev-tools/toolbar";
import { CORE_TOOLS } from "discourse/static/dev-tools/tools";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import { i18n } from "discourse-i18n";

/**
 * The toolbar as it is meant to read, left to right. Spelled out rather than
 * derived from the tool table, so that the two assertions below can disagree:
 * one holds the rendered toolbar to this order, the other holds the table to
 * it. Deriving it would let both move together and catch neither.
 */
const EXPECTED_ORDER = [
  "gripper",
  "plugin-outlet-debug",
  "block-debug",
  "upcoming-changes-debug",
  "safe-mode",
  "verbose-localization",
  "styleguide",
  "disable-dev-tools",
];

const SELECTORS = {
  gripper: ".gripper",
  "plugin-outlet-debug": ".toggle-plugin-outlets",
  "block-debug": ".toggle-blocks",
  "upcoming-changes-debug": ".toggle-upcoming-changes-menu",
  "safe-mode": ".toggle-safe-mode",
  "verbose-localization": ".toggle-verbose-localization",
  styleguide: ".open-styleguide",
  "disable-dev-tools": ".disable-dev-tools",
};

/**
 * The order the toolbar's landmarks appear in, read back from the rendered DOM.
 * Matches descendants rather than direct children, so a tool that wraps its
 * button is still found, and reports repeats rather than collapsing them, so a
 * landmark rendered twice fails instead of reading back as one.
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

/**
 * The toolbar positions itself with `top: min(100dvh - <own height>px, <top>px)`,
 * so the tracked value is read back out of the declaration rather than guessed at.
 *
 * @returns {number} The pixel value the toolbar last wrote for its own top.
 */
function declaredTop() {
  const style = find(".dev-tools-toolbar").getAttribute("style");
  return parseFloat(style.match(/,\s*(-?[\d.]+)px\)/)[1]);
}

module("Integration | Component | DevTools | Toolbar", function (hooks) {
  setupRenderingTest(hooks);

  test("dragging the gripper moves the toolbar by the pointer's travel", async function (assert) {
    await render(<template><Toolbar /></template>);

    const gripper = find(".dev-tools-toolbar .gripper");
    stubPointerCapture(gripper);
    // Where the toolbar actually sits, so the grab offset can be asserted rather
    // than cancelled out by comparing two dragged positions.
    const realTop = find(".dev-tools-toolbar").getBoundingClientRect().top;

    await triggerEvent(gripper, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });
    await triggerEvent(gripper, "pointermove", {
      pointerId: 1,
      clientX: 10,
      clientY: 340,
      pageX: 10,
      pageY: 340,
    });
    const settled = declaredTop();

    assert.strictEqual(
      settled,
      realTop + 40,
      "the toolbar keeps the offset it was grabbed at, so it follows the pointer from where the user picked it up rather than jumping its edge to the cursor"
    );

    await triggerEvent(gripper, "pointermove", {
      pointerId: 1,
      clientX: 10,
      clientY: 380,
      pageX: 10,
      pageY: 380,
    });

    assert.strictEqual(
      declaredTop() - settled,
      40,
      "further travel moves the toolbar one pixel per pixel"
    );

    await triggerEvent(gripper, "pointerup", {
      pointerId: 1,
      clientX: 10,
      clientY: 340,
      pageX: 10,
      pageY: 340,
    });
    assert
      .dom(".dev-tools-toolbar")
      .doesNotHaveClass(
        "--dragging",
        "releasing the pointer ends the drag session"
      );
  });

  test("the gripper is marked as dragging only while the pointer is down", async function (assert) {
    await render(<template><Toolbar /></template>);

    const gripper = find(".dev-tools-toolbar .gripper");
    stubPointerCapture(gripper);

    assert
      .dom(".dev-tools-toolbar")
      .doesNotHaveClass("--dragging", "idle to begin with");

    await triggerEvent(gripper, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });

    assert
      .dom(".dev-tools-toolbar")
      .hasClass("--dragging", "a press opens a drag session");
    assert
      .dom(document.body)
      .hasClass("dragging", "and marks the page so the cursor holds");

    await triggerEvent(gripper, "pointerup", {
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });

    assert
      .dom(document.body)
      .doesNotHaveClass("dragging", "the page mark is given back on release");
  });

  test("grabbing the toolbar at its exact top edge still opens a drag session", async function (assert) {
    await render(<template><Toolbar /></template>);

    const gripper = find(".dev-tools-toolbar .gripper");
    stubPointerCapture(gripper);
    // A press here yields a grab offset of exactly 0, which is the value a
    // truthiness check on the offset silently reads as "not dragging".
    const realTop = find(".dev-tools-toolbar").getBoundingClientRect().top;

    await triggerEvent(gripper, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 10,
      clientY: realTop,
      pageX: 10,
      pageY: realTop,
    });

    assert
      .dom(".dev-tools-toolbar")
      .hasClass("--dragging", "a zero grab offset is still a live drag");

    await triggerEvent(gripper, "pointerup", {
      pointerId: 1,
      clientX: 10,
      clientY: realTop,
      pageX: 10,
      pageY: realTop,
    });

    assert
      .dom(".dev-tools-toolbar")
      .doesNotHaveClass("--dragging", "and it still closes on release");
  });

  test("a cancelled gesture closes the drag session too", async function (assert) {
    await render(<template><Toolbar /></template>);

    const gripper = find(".dev-tools-toolbar .gripper");
    stubPointerCapture(gripper);

    await triggerEvent(gripper, "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 10,
      clientY: 300,
      pageX: 10,
      pageY: 300,
    });
    await triggerEvent(gripper, "pointermove", {
      pointerId: 1,
      clientX: 10,
      clientY: 380,
      pageX: 10,
      pageY: 380,
    });
    const dragged = declaredTop();
    await triggerEvent(gripper, "pointercancel", { pointerId: 1 });

    assert
      .dom(".dev-tools-toolbar")
      .doesNotHaveClass(
        "--dragging",
        "an interrupted gesture does not leave the toolbar stuck dragging"
      );
    assert
      .dom(document.body)
      .doesNotHaveClass(
        "dragging",
        "the cancelled gesture releases the page mark"
      );
    assert.strictEqual(
      declaredTop(),
      dragged,
      "the interruption commits rather than discards, so the toolbar stays where it was dragged to instead of snapping back"
    );
  });

  test("renders every tool, in order, between the gripper and the disable button", async function (assert) {
    this.site.can_see_styleguide = true;

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

  test("renders the styleguide link for visitors with access", async function (assert) {
    this.site.can_see_styleguide = true;

    await render(<template><Toolbar /></template>);

    assert
      .dom(".open-styleguide")
      .hasAttribute("href", "/styleguide", "the link targets the styleguide")
      .hasAttribute(
        "title",
        i18n("dev_tools.open_styleguide"),
        "the link has a visible tooltip"
      )
      .hasAttribute(
        "aria-label",
        i18n("dev_tools.open_styleguide"),
        "the icon-only link has an accessible name"
      )
      .hasAttribute(
        "data-auto-route",
        "true",
        "the link performs a full navigation so filtered assets load"
      );
    assert
      .dom(".open-styleguide .d-icon-paintbrush")
      .exists("the link uses the styleguide icon");
  });

  test("styles links and buttons as consistent toolbar controls", async function (assert) {
    this.site.can_see_styleguide = true;
    const competingLinkStyle = document.createElement("style");
    competingLinkStyle.textContent = "a:any-link { color: rgb(0 0 255); }";
    document.head.append(competingLinkStyle);

    await render(<template><Toolbar /></template>);

    const buttonStyle = getComputedStyle(find(".toggle-plugin-outlets"));
    const linkStyle = getComputedStyle(find(".open-styleguide"));
    const buttonIconStyle = getComputedStyle(
      find(".toggle-plugin-outlets .d-icon")
    );
    const linkIconStyle = getComputedStyle(find(".open-styleguide .d-icon"));

    assert.strictEqual(
      buttonStyle.borderTopWidth,
      "0px",
      "toolbar buttons have no native border"
    );
    assert.strictEqual(
      buttonStyle.paddingTop,
      "5px",
      "toolbar buttons retain their compact padding"
    );
    assert.strictEqual(
      linkStyle.borderTopWidth,
      buttonStyle.borderTopWidth,
      "toolbar links match the button border"
    );
    assert.strictEqual(
      linkStyle.paddingTop,
      buttonStyle.paddingTop,
      "toolbar links match the button padding"
    );
    assert.strictEqual(
      linkStyle.color,
      buttonStyle.color,
      "toolbar links match the button foreground color"
    );
    assert.strictEqual(
      linkIconStyle.color,
      buttonIconStyle.color,
      "toolbar link icons match button icon colors"
    );

    competingLinkStyle.remove();
  });

  test("omits the styleguide link without access", async function (assert) {
    await render(<template><Toolbar /></template>);

    assert
      .dom(".open-styleguide")
      .doesNotExist("a missing capability does not expose the link");
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
