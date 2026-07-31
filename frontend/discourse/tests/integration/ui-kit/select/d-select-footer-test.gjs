import { on } from "@ember/modifier";
import {
  click,
  find,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { forceMobile } from "discourse/lib/mobile";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { ITEMS } from "discourse/tests/helpers/d-select-hosts";
import DSelect from "discourse/ui-kit/select/d-select";

module("Integration | ui-kit | select | DSelect (:footer)", function (hooks) {
  setupRenderingTest(hooks);

  test("the :footer block renders as a labeled region below the listbox", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    assert
      .dom(".d-combobox__panel > .d-combobox__footer")
      .exists("the footer is a panel child, pinned below the list");
    assert.dom(".d-combobox__footer").hasAttribute("role", "group");
    assert.dom(".d-combobox__footer").hasAttribute("aria-label", /.+/);
    assert
      .dom("[role='listbox'] .d-combobox__footer")
      .doesNotExist("the footer is NOT inside the listbox");
    assert.dom(".d-combobox__footer .test-footer-btn").exists();
  });

  test("the footer's controls are keyboard-reachable focusables inside the popup content", async function (assert) {
    // float-kit's `forwardTabToContent` focuses the first focusable inside the popup content on
    // Tab from the trigger; the footer's control must therefore live in the content region and
    // be focusable, and focusing it (as the forward does) must keep the menu open.
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    const btn = find(".d-combobox__footer .test-footer-btn");
    assert.true(
      find("[data-content]").contains(btn),
      "the footer control lives inside the popup content region float-kit forwards Tab into"
    );

    btn.focus();
    await settled();
    assert
      .dom("[role='listbox']")
      .exists("focusing the footer control keeps the menu open");
  });

  test("clicking the footer keeps the menu open", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    await click(".test-footer-btn");

    assert
      .dom("[role='listbox']")
      .exists("a footer click does not dismiss the menu");
  });

  test("desktop: focus leaving the footer to outside the widget closes the menu", async function (assert) {
    await render(
      <template>
        <button type="button" class="outside-btn">outside</button>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    const footerBtn = find(".test-footer-btn");
    footerBtn.focus();
    await triggerEvent(footerBtn, "focusout", {
      relatedTarget: find(".outside-btn"),
    });

    assert
      .dom("[role='listbox']")
      .doesNotExist(
        "focus leaving the footer to an outside control closes the menu"
      );
  });

  test("desktop: focus moving within the footer or back to the input keeps the menu open", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
            <button type="button" class="test-footer-btn2">Act2</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    const btn1 = find(".test-footer-btn");
    btn1.focus();

    await triggerEvent(btn1, "focusout", {
      relatedTarget: find(".test-footer-btn2"),
    });
    assert
      .dom("[role='listbox']")
      .exists("an intra-footer focus move stays open");

    await triggerEvent(btn1, "focusout", {
      relatedTarget: find("[role='combobox']"),
    });
    assert.dom("[role='listbox']").exists("footer → input stays open");
  });

  test("Escape from the footer closes the menu", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    find(".test-footer-btn").focus();
    await triggerKeyEvent(".test-footer-btn", "keydown", "Escape");

    assert
      .dom("[role='listbox']")
      .doesNotExist("Escape from the footer closes");
  });

  test("ArrowDown from the input navigates options and never the footer", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}}>
          <:footer>
            <button type="button" class="test-footer-btn">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");
    await triggerKeyEvent("[role='combobox']", "keydown", "ArrowDown");

    const id = find("[role='combobox']").getAttribute("aria-activedescendant");
    const active = id ? document.getElementById(id) : null;
    assert.strictEqual(
      active?.getAttribute("role"),
      "option",
      "arrow navigation stays within the listbox"
    );
  });

  test("the :footer block receives the dropdown state", async function (assert) {
    await render(
      <template>
        <DSelect @items={{ITEMS}} @value={{1}}>
          <:footer as |state|>
            <span class="test-total">{{state.total}}</span>
            <span class="test-hasvalue">{{if state.hasValue "yes" "no"}}</span>
            <button
              type="button"
              class="test-close"
              {{on "click" state.close}}
            >close</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    assert
      .dom(".test-total")
      .hasText(String(ITEMS.length), "the full result count is yielded");
    assert.dom(".test-hasvalue").hasText("yes", "hasValue is yielded");

    await click(".test-close");
    assert
      .dom("[role='listbox']")
      .doesNotExist("the yielded close() dismisses the menu");
  });

  test("the yielded loadedCount shares total's population (excludes specials)", async function (assert) {
    const specialItems = () => [{ id: 0, name: "None" }];
    await render(
      <template>
        <DSelect @items={{ITEMS}} @specialItems={{specialItems}}>
          <:footer as |state|>
            <span class="test-total">{{state.total}}</span>
            <span class="test-loaded">{{state.loadedCount}}</span>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    assert.dom(".test-total").hasText("3", "total counts the source options");
    assert
      .dom(".test-loaded")
      .hasText(
        "3",
        "loadedCount matches total's population — the special row is not counted"
      );
  });
});

module(
  "Integration | ui-kit | select | DSelect (:footer, mobile)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      forceMobile();
    });

    test("moving focus within the footer does NOT close the modal", async function (assert) {
      await render(
        <template>
          <DSelect @items={{ITEMS}}>
            <:footer>
              <button type="button" class="test-footer-btn">Act</button>
              <button type="button" class="test-footer-btn2">Act2</button>
            </:footer>
          </DSelect>
        </template>
      );
      await click(".d-combobox__trigger");
      assert
        .dom(".fk-d-menu-modal .d-combobox__footer")
        .exists("the footer renders inside the modal");

      const btn1 = find(".fk-d-menu-modal .test-footer-btn");
      btn1.focus();
      await triggerEvent(btn1, "focusout", {
        relatedTarget: find(".fk-d-menu-modal .test-footer-btn2"),
      });

      assert
        .dom(".fk-d-menu-modal [role='listbox']")
        .exists("an intra-footer focus move leaves the mobile modal open");
    });
  }
);
