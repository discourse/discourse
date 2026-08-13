import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const estimate = () => 40;
const items = Array.from({ length: 100 }, (_, index) => ({
  id: index,
  text: `Row ${index}`,
}));

module("Integration | ui-kit | DVirtualList | rendering", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    disableVirtualization();
  });

  hooks.afterEach(function () {
    enableVirtualization();
  });

  test("uses the semantic inner container and absolutely positioned owned rows when windowing", async function (assert) {
    enableVirtualization();

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList
          @items={{items}}
          @estimateSize={{estimate}}
          @as="ul"
          @role="listbox"
          @ownedRow={{true}}
          as |item row|
        >
          {{! eslint-disable ember/template-require-context-role }}
          <li
            class="row"
            role="option"
            data-index={{row.index}}
            style="height: 40px"
            {{row.place row.start row.index}}
          >
            {{item.text}}
          </li>
        </DVirtualList>
      </template>
    );

    assert
      .dom("ul[role='listbox']")
      .exists("the semantic inner container exists");
    assert
      .dom("ul[role='listbox'] .row[role='option']")
      .exists("the semantic inner container carries the owned options");
    assert
      .dom(".d-virtual-list")
      .doesNotHaveAttribute(
        "role",
        "the primitive-owned viewport is role-less"
      );

    const rows = findAll(".row");
    assert.true(rows.length > 0, "mounts some rows");
    assert.true(rows.length < items.length, "mounts a bounded window");

    for (const row of rows) {
      assert.strictEqual(
        getComputedStyle(row).position,
        "absolute",
        `row ${row.dataset.index} is absolutely positioned`
      );
      assert.notStrictEqual(
        getComputedStyle(row).transform,
        "none",
        `row ${row.dataset.index} is translated to its virtual position`
      );
      assert.strictEqual(
        row.textContent.trim(),
        items[Number(row.dataset.index)].text,
        "the yielded index identifies the matching item"
      );
    }
  });

  test("keeps owned rows in normal flow when virtualization is disabled", async function (assert) {
    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
        </style>
        <DVirtualList
          @items={{items}}
          @estimateSize={{estimate}}
          @as="ul"
          @role="listbox"
          @ownedRow={{true}}
          as |item row|
        >
          {{! eslint-disable ember/template-require-context-role }}
          <li
            class="row"
            role="option"
            data-index={{row.index}}
            style="height: 40px"
            {{row.place row.start row.index}}
          >
            {{item.text}}
          </li>
        </DVirtualList>
      </template>
    );

    const rows = findAll(".row");
    assert.strictEqual(rows.length, items.length, "renders every fallback row");

    let previousTop = -Infinity;
    for (const row of rows) {
      assert.strictEqual(
        getComputedStyle(row).position,
        "static",
        `row ${row.dataset.index} remains in normal flow`
      );
      assert.strictEqual(
        getComputedStyle(row).transform,
        "none",
        `row ${row.dataset.index} is not translated`
      );
      assert.true(
        row.getBoundingClientRect().top > previousTop,
        `row ${row.dataset.index} is below its predecessor`
      );
      previousTop = row.getBoundingClientRect().top;
    }
  });

  test("puts role and splatted attributes on the semantic inner container", async function (assert) {
    await render(
      <template>
        <DVirtualList
          @items={{items}}
          @estimateSize={{estimate}}
          @as="ul"
          @role="listbox"
          @ownedRow={{true}}
          id="my-listbox"
          as |item row|
        >

          <li
            class="row"
            role="option"
            data-index={{row.index}}
            {{row.place row.start row.index}}
          >
            {{item.text}}
          </li>
        </DVirtualList>
      </template>
    );

    assert
      .dom("ul")
      .hasAttribute("role", "listbox", "the inner container owns the role");
    assert
      .dom("ul")
      .hasAttribute(
        "id",
        "my-listbox",
        "the inner container receives attributes"
      );
    assert
      .dom(".d-virtual-list")
      .doesNotHaveAttribute("role", "the viewport has no consumer role");
    assert
      .dom(".d-virtual-list")
      .doesNotHaveAttribute("id", "the viewport has no consumer id");
  });

  // A browser with keyboard-focusable scrollers puts a scroll container into the tab sequence
  // when it holds nothing focusable, and does so without marking the element: adopted or not, it
  // reports `tabIndex === -1` and matches no focusable selector. An explicit attribute is
  // therefore both the only way to suppress the adoption and the only part of it a test can read.
  test("leaves the viewport's tab behaviour to the browser by default", async function (assert) {
    await render(
      <template>
        <DVirtualList @items={{items}} @estimateSize={{estimate}} as |item|>
          {{item.text}}
        </DVirtualList>
      </template>
    );

    assert
      .dom(".d-virtual-list")
      .doesNotHaveAttribute(
        "tabindex",
        "a list read by scrolling keeps whatever access the browser gives it"
      );
  });

  test("opts the viewport out of the tab sequence on request", async function (assert) {
    await render(
      <template>
        <DVirtualList
          @items={{items}}
          @estimateSize={{estimate}}
          @viewportTabbable={{false}}
          as |item|
        >
          {{item.text}}
        </DVirtualList>
      </template>
    );

    assert.dom(".d-virtual-list").hasAttribute("tabindex", "-1");
  });
});
