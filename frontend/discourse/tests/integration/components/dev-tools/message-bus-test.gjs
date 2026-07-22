import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MessageBusButton from "discourse/static/dev-tools/message-bus/button";
import {
  install,
  uninstall,
} from "discourse/static/dev-tools/message-bus/instrumentation";
import devToolsState from "discourse/static/dev-tools/state";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const TOGGLE = ".toggle-message-bus";
const PANEL = ".d-dock-panel.dev-tools-message-bus";

module("Integration | Component | dev-tools | message-bus", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.originalCallbacks = [...window.MessageBus.callbacks];
    window.MessageBus.callbacks.length = 0;
    install();
  });

  hooks.afterEach(function () {
    uninstall();
    window.MessageBus.callbacks.length = 0;
    window.MessageBus.callbacks.push(...this.originalCallbacks);
    devToolsState.setFlag("message-bus", "open", false);
  });

  test("the panel is closed until the tool is toggled", async function (assert) {
    await render(<template><MessageBusButton /></template>);

    assert.dom(TOGGLE).exists("the toolbar entry renders");
    assert.dom(PANEL).doesNotExist();

    await click(TOGGLE);
    assert.dom(PANEL).exists("toggling opens the panel");
    assert.dom(TOGGLE).hasClass("--active");

    await click(TOGGLE);
    assert.dom(PANEL).doesNotExist("toggling again closes it");
  });

  test("the open state is kept in the developer tools state", async function (assert) {
    await render(<template><MessageBusButton /></template>);
    await click(TOGGLE);

    assert.true(
      devToolsState.getFlag("message-bus", "open"),
      "so it survives a re-render and a reload"
    );
  });

  test("lists the current subscriptions", async function (assert) {
    window.MessageBus.subscribe("/alpha", () => {});
    window.MessageBus.subscribe("/beta", () => {});

    await render(<template><MessageBusButton /></template>);
    await click(TOGGLE);

    const channels = [
      ...document.querySelectorAll(
        ".dev-tools-message-bus__subscriptions tbody tr td:first-child"
      ),
    ].map((cell) => cell.textContent.trim());

    assert.deepEqual(channels, ["/alpha", "/beta"]);
  });

  test("marks a channel that is subscribed more than once", async function (assert) {
    window.MessageBus.subscribe("/twice", () => {});
    window.MessageBus.subscribe("/twice", () => {});
    window.MessageBus.subscribe("/once", () => {});

    await render(<template><MessageBusButton /></template>);
    await click(TOGGLE);

    assert
      .dom(".dev-tools-message-bus__subscriptions tr.--duplicated")
      .exists(
        { count: 2 },
        "both subscriptions on the duplicated channel are flagged"
      );
  });

  test("says so when nothing has been received", async function (assert) {
    await render(<template><MessageBusButton /></template>);
    await click(TOGGLE);

    assert.dom(".dev-tools-message-bus__empty").exists();
  });

  test("the close control shuts the panel", async function (assert) {
    await render(<template><MessageBusButton /></template>);
    await click(TOGGLE);
    await click(".dev-tools-message-bus__close");

    assert.dom(PANEL).doesNotExist();
    assert.false(devToolsState.getFlag("message-bus", "open"));
  });
});
