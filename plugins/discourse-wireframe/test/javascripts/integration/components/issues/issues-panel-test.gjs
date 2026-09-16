import Service from "@ember/service";
import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import IssuesPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/issues/issues-panel";

class StubValidation extends Service {
  issues = [];

  get validationIssues() {
    return this.issues;
  }
}

// Registers a canned validation service and returns the selection / reveal
// services with their navigation methods spied, so a click can be asserted
// without standing up the real selection + layout machinery.
function setup(owner, issues) {
  owner.register("service:wireframe-validation", StubValidation);
  owner.lookup("service:wireframe-validation").issues = issues;

  const selection = owner.lookup("service:wireframe-selection");
  const reveal = owner.lookup("service:wireframe-block-reveal");
  const calls = { selected: null, flashed: null };
  selection.selectBlock = ({ key }) => (calls.selected = key);
  reveal.flash = (key) => (calls.flashed = key);
  return calls;
}

module(
  "Integration | discourse-wireframe | Component | issues-panel",
  function (hooks) {
    setupRenderingTest(hooks);

    test("groups issues by outlet and lists each block's messages", async function (assert) {
      setup(this.owner, [
        {
          outletName: "homepage-blocks",
          blockKey: "cta:1",
          blockName: "cta",
          messages: [
            { id: "field:title", text: "title: Required." },
            { id: "field:href", text: "href: Required." },
          ],
        },
        {
          outletName: "sidebar-blocks",
          blockKey: "hero:2",
          blockName: "hero",
          messages: [{ id: "field:kind", text: "Must be one of: a, b." }],
        },
      ]);

      await render(<template><IssuesPanel /></template>);

      assert.dom(".wireframe-issues__outlet").exists({ count: 2 });
      assert
        .dom(
          ".wireframe-issues__outlet:first-child .wireframe-issues__item-block"
        )
        .hasText("cta");
      assert
        .dom(
          ".wireframe-issues__outlet:first-child .wireframe-issues__messages li"
        )
        .exists({ count: 2 }, "lists both messages for the block");
    });

    test("renders the empty state when there are no issues", async function (assert) {
      setup(this.owner, []);
      await render(<template><IssuesPanel /></template>);

      assert.dom(".wireframe-issues__item").doesNotExist();
      assert.dom(".wireframe-issues .panel-empty").exists();
    });

    test("clicking an issue selects and reveals its block", async function (assert) {
      const calls = setup(this.owner, [
        {
          outletName: "homepage-blocks",
          blockKey: "cta:1",
          blockName: "cta",
          messages: [{ id: "field:title", text: "title: Required." }],
        },
      ]);

      await render(<template><IssuesPanel /></template>);
      await click(".wireframe-issues__item");

      assert.strictEqual(calls.selected, "cta:1", "selects the block");
      assert.strictEqual(calls.flashed, "cta:1", "flashes the block");
    });

    test("Enter activates a keyboard-focused issue row", async function (assert) {
      const calls = setup(this.owner, [
        {
          outletName: "homepage-blocks",
          blockKey: "cta:1",
          blockName: "cta",
          messages: [{ id: "field:title", text: "title: Required." }],
        },
      ]);

      await render(<template><IssuesPanel /></template>);
      await triggerKeyEvent(".wireframe-issues__item", "keydown", "Enter");

      assert.strictEqual(calls.selected, "cta:1", "Enter selects the block");
    });

    test("an issue with no block key renders as a non-interactive record", async function (assert) {
      setup(this.owner, [
        {
          outletName: "homepage-blocks",
          blockKey: null,
          blockName: "(unknown)",
          messages: [
            { id: "code:unregistered-block:", text: "Block isn't registered." },
          ],
        },
      ]);

      await render(<template><IssuesPanel /></template>);

      assert.dom(".wireframe-issues__item.--static").exists();
      assert
        .dom(".wireframe-issues__item.--static")
        .doesNotHaveAttribute("role", "the static row is not a button");
    });
  }
);
