import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | lib | load-accessible-name", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(async function () {
    this.accessibleName = await loadAccessibleName();
  });

  test("prefers aria-label over content, as assistive tech does", async function (assert) {
    await render(
      <template>
        <button class="a" aria-label="Save changes">Save</button>
      </template>
    );

    assert.strictEqual(
      this.accessibleName(document.querySelector(".a")),
      "Save changes",
      "matching on content rather than the name would match text nobody hears"
    );
  });

  test("resolves aria-labelledby across elements", async function (assert) {
    await render(
      <template>
        <span id="an-label">Orange</span>
        <span id="an-hint">Press Backspace to remove</span>
        <button class="a" aria-labelledby="an-label an-hint">x</button>
      </template>
    );

    assert.strictEqual(
      this.accessibleName(document.querySelector(".a")),
      "Orange Press Backspace to remove",
      "a hint folded into the NAME becomes part of what type-ahead matches, which is why it belongs in aria-describedby"
    );
  });

  test("includes text contributed by a pseudo-element", async function (assert) {
    await render(
      <template>
        {{! eslint-disable ember/template-no-forbidden-elements }}
        <style>
          .an-pseudo::before {
            content: "Bold";
          }
        </style>
        <button class="a an-pseudo"></button>
      </template>
    );

    assert.strictEqual(
      this.accessibleName(document.querySelector(".a")),
      "Bold",
      "the library drops this by default, so an item labelled through CSS would be unmatchable"
    );
  });

  test("an inert element has no name to announce", async function (assert) {
    await render(
      <template>
        <div inert>
          <button class="a">Cut</button>
        </div>
      </template>
    );

    assert.strictEqual(
      this.accessibleName(document.querySelector(".a")),
      "",
      "inert removes the subtree from the accessibility tree, and the library does not implement it"
    );
  });

  test("ignores an aria-hidden descendant", async function (assert) {
    await render(
      <template>
        <button class="a">Save<span aria-hidden="true">(icon)</span></button>
      </template>
    );

    assert.strictEqual(
      this.accessibleName(document.querySelector(".a")),
      "Save",
      "decorative content is not announced, so it must not be matchable either"
    );
  });
});
