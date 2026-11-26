import { tracked } from "@glimmer/tracking";
import { render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import { clearHTMLCache, setCustomHTML } from "discourse/helpers/custom-html";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DCustomHtml from "discourse/ui-kit/d-custom-html";

module("Integration | ui-kit | DCustomHtml", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    clearHTMLCache();
  });

  test("renders the custom HTML registered under @name", async function (assert) {
    setCustomHTML("test-top", "<p class='custom'>Hello</p>");

    await render(
      <template><DCustomHtml class="wrapper" @name="test-top" /></template>
    );

    assert
      .dom(".wrapper p.custom")
      .hasText("Hello", "the HTML is rendered, not escaped");
  });

  test("announces insertion and removal with @triggerAppEvent", async function (assert) {
    setCustomHTML("test-top", "<p>Hello</p>");
    const appEvents = this.owner.lookup("service:app-events");
    const events = [];
    const inserted = () => events.push("inserted");
    const destroyed = () => events.push("destroyed");
    appEvents.on("inserted-custom-html:test-top", inserted);
    appEvents.on("destroyed-custom-html:test-top", destroyed);
    const shown = tracked(true);

    await render(
      <template>
        {{#if shown.value}}
          <DCustomHtml @name="test-top" @triggerAppEvent={{true}} />
        {{/if}}
      </template>
    );
    shown.value = false;
    await rerender();

    appEvents.off("inserted-custom-html:test-top", inserted);
    appEvents.off("destroyed-custom-html:test-top", destroyed);
    assert.deepEqual(
      events,
      ["inserted", "destroyed"],
      "both app events are triggered"
    );
  });

  test("stays quiet without @triggerAppEvent", async function (assert) {
    setCustomHTML("test-top", "<p>Hello</p>");
    const appEvents = this.owner.lookup("service:app-events");
    const events = [];
    const inserted = () => events.push("inserted");
    appEvents.on("inserted-custom-html:test-top", inserted);

    await render(<template><DCustomHtml @name="test-top" /></template>);

    appEvents.off("inserted-custom-html:test-top", inserted);
    assert.deepEqual(events, [], "no app event is triggered");
  });
});
