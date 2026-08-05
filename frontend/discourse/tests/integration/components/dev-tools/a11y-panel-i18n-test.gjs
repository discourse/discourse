import { click, focus, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  findingKey,
  ruleIds,
  tierOf,
} from "discourse/static/dev-tools/a11y/findings";
import * as instrumentation from "discourse/static/dev-tools/a11y/instrumentation";
import A11yPanel from "discourse/static/dev-tools/a11y/panel";
import { clearDockPanels, closeDock } from "discourse/static/dev-tools/dock";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

/**
 * Oracle for the panel rewrite (unit 5): translation, the trace/display split,
 * selectable rows, and tier-aware ranking.
 *
 * Two things are being separated here that used to be one string. What a rule
 * DISPLAYS is translated and free to change. What a rule TRACES is a stable
 * ascii id, because that string is what someone pastes into a bug report and
 * what the text filter matches — and neither of those may depend on the reader's
 * locale.
 *
 * The tier split is the other half. `broken` colours the row and feeds the
 * problems filter; `fragile` is a quiet marker outside it; `noted` is plain text
 * that never ranks. A filter that keeps everything ranks nothing, which is the
 * failure this whole rebuild exists to undo.
 */
module(
  "Integration | Component | dev-tools | a11y-panel-i18n",
  function (hooks) {
    setupRenderingTest(hooks);

    let fixtures;

    hooks.beforeEach(function () {
      fixtures = [];
      this.a11y = this.owner.lookup("service:a11y");
    });

    hooks.afterEach(function () {
      fixtures.forEach((fixture) => fixture.remove());
      instrumentation.resetA11yInstrumentation();
      closeDock();
      clearDockPanels();
    });

    function addFixture(html) {
      const host = document.createElement("div");
      host.innerHTML = html;
      document.body.appendChild(host);
      fixtures.push(host);

      return host;
    }

    /*
     * The gate that was deferred out of unit 1b until the strings existed.
     *
     * A rule that gains a detector without a translation renders a missing-key
     * marker in the panel, and nothing else catches that: the registry knows the
     * id is real and the locale file simply has no entry. This is the only test
     * that fails when someone adds rule 28 and forgets the string.
     */
    test("every registered rule has a translation", function (assert) {
      for (const id of ruleIds()) {
        const key = findingKey(id);
        const translated = i18n(key);

        assert.false(
          translated.startsWith("["),
          `${id} resolves ${key} to a real string, not a missing-key marker`
        );
      }
    });

    test("a rule's displayed text is its translation, not text authored in the panel", async function (assert) {
      const host = addFixture(
        `<div id="subject" role="listbox" aria-label="Categories" tabindex="0" aria-activedescendant="gone"></div>`
      );
      instrumentation.attachCapture();
      await focus(host.querySelector("#subject"));
      await render(<template><A11yPanel /></template>);

      assert
        .dom(".dev-tools-a11y__problem")
        .hasText(i18n(findingKey("cursor.dangling")));
    });

    // A pasted trace has to read the same for everyone. Translating it would make
    // a bug report unsearchable by the person who receives it.
    test("a copied trace carries rule ids, never translated text", async function (assert) {
      const host = addFixture(
        `<div id="subject" role="listbox" aria-label="Categories" tabindex="0" aria-activedescendant="gone"></div>`
      );
      instrumentation.attachCapture();
      await focus(host.querySelector("#subject"));

      const trace = instrumentation.copyTrace();

      assert.true(trace.includes("cursor.dangling"), "the id is in the trace");
      assert.false(
        trace.includes(i18n(findingKey("cursor.dangling"))),
        "and the translation is not"
      );
    });

    // The inspector used to show the newest event and nothing else, so a trace was
    // only readable while whatever you were investigating was still the last thing
    // that happened.
    test("selecting a row inspects that row, not the newest one", async function (assert) {
      const host = addFixture(`
      <button id="first" aria-label="First">a</button>
      <button id="second" aria-label="Second">b</button>
    `);
      instrumentation.attachCapture();
      await focus(host.querySelector("#first"));
      await focus(host.querySelector("#second"));
      await render(<template><A11yPanel /></template>);

      assert.dom(".dev-tools-a11y__inspector").includesText("Second");

      // The event rows specifically: watching the regions records a meta row of
      // its own, and it is first, and it has no snapshot to inspect.
      await click(".dev-tools-a11y__entry.--event");

      assert
        .dom(".dev-tools-a11y__inspector")
        .includesText("First", "the inspector follows the selection");
    });

    test("the selected row is marked as selected", async function (assert) {
      const host = addFixture(
        `<button id="subject" aria-label="Only">a</button>`
      );
      instrumentation.attachCapture();
      await focus(host.querySelector("#subject"));
      await render(<template><A11yPanel /></template>);

      await click(".dev-tools-a11y__entry.--event");

      assert.dom(".dev-tools-a11y__entry.--selected").exists({ count: 1 });
    });

    // Ranking is the whole point of the filter. A NOTED observation kept by it
    // would put every icon button in the product back in the list.
    test("the problems filter keeps only what ranks", async function (assert) {
      const host = addFixture(`
      <div id="broken" role="listbox" aria-label="Categories" tabindex="0" aria-activedescendant="gone"></div>
      <a id="noted" href="#" title="Admin">Admin</a>
    `);
      instrumentation.attachCapture();
      await focus(host.querySelector("#broken"));
      await focus(host.querySelector("#noted"));
      await render(<template><A11yPanel /></template>);

      await click(".dev-tools-a11y__problems-toggle");

      assert
        .dom(".dev-tools-a11y__entry")
        .exists({ count: 1 }, "the noted row is not a problem");
    });

    test("a noted observation is shown, just never as a problem", async function (assert) {
      const host = addFixture(
        `<a id="subject" href="#" title="Admin">Admin</a>`
      );
      instrumentation.attachCapture();
      await focus(host.querySelector("#subject"));
      await render(<template><A11yPanel /></template>);

      assert.dom(".dev-tools-a11y__entry.--event").exists({ count: 1 });
      assert
        .dom(".dev-tools-a11y__problem")
        .doesNotExist("an observation is not a defect");
    });

    // Guards the split from the other side: no rule may be given wording in the
    // panel, because wording that lives there cannot be translated.
    test("the panel authors no rule wording of its own", function (assert) {
      const noted = ruleIds().filter((id) => tierOf(id) === "noted");

      assert.true(noted.length > 0, "there are noted rules to check");
      for (const id of noted) {
        assert.false(
          i18n(findingKey(id)).startsWith("["),
          `${id} is translated rather than described in the panel`
        );
      }
    });
  }
);
