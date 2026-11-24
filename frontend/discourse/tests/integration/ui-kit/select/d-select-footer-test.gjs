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
        <DSelect @options={{ITEMS}}>
          <:footer>
            <button class="test-footer-btn" type="button">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    assert
      .dom(".d-select__panel > .d-select__footer")
      .exists("the footer is a panel child, pinned below the list");
    assert.dom(".d-select__footer").hasAttribute("role", "group");
    assert.dom(".d-select__footer").hasAttribute("aria-label", /.+/);
    assert
      .dom("[role='listbox'] .d-select__footer")
      .doesNotExist("the footer is NOT inside the listbox");
    assert.dom(".d-select__footer .test-footer-btn").exists();
  });

  test("the footer's controls are keyboard-reachable focusables inside the popup content", async function (assert) {
    // float-kit's `forwardTabToContent` focuses the first focusable inside the popup content on
    // Tab from the trigger; the footer's control must therefore live in the content region and
    // be focusable, and focusing it (as the forward does) must keep the menu open.
    await render(
      <template>
        <DSelect @options={{ITEMS}}>
          <:footer>
            <button class="test-footer-btn" type="button">Act</button>
          </:footer>
        </DSelect>
      </template>
    );
    await click("[role='combobox']");

    const btn = find(".d-select__footer .test-footer-btn");
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
        <DSelect @options={{ITEMS}}>
          <:footer>
            <button class="test-footer-btn" type="button">Act</button>
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
        <button class="outside-btn" type="button">outside</button>
        <DSelect @options={{ITEMS}}>
          <:footer>
            <button class="test-footer-btn" type="button">Act</button>
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
        <DSelect @options={{ITEMS}}>
          <:footer>
            <button class="test-footer-btn" type="button">Act</button>
            <button class="test-footer-btn2" type="button">Act2</button>
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
        <DSelect @options={{ITEMS}}>
          <:footer>
            <button class="test-footer-btn" type="button">Act</button>
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
        <DSelect @options={{ITEMS}}>
          <:footer>
            <button class="test-footer-btn" type="button">Act</button>
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
        <DSelect @options={{ITEMS}} @value={{1}}>
          <:footer as |state|>
            <span class="test-total">{{state.total}}</span>
            <span class="test-hasvalue">{{if state.hasValue "yes" "no"}}</span>
            <button
              class="test-close"
              type="button"
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
    const extraOptions = () => [{ id: 0, name: "None" }];
    await render(
      <template>
        <DSelect @extraOptions={{extraOptions}} @options={{ITEMS}}>
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
          <DSelect @options={{ITEMS}}>
            <:footer>
              <button class="test-footer-btn" type="button">Act</button>
              <button class="test-footer-btn2" type="button">Act2</button>
            </:footer>
          </DSelect>
        </template>
      );
      await click(".d-select__trigger");
      assert
        .dom(".fk-d-menu-modal .d-select__footer")
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

/** A recipe that forwards its caller's footer, the way the tag recipes do. */
const ForwardingSelect = <template>
  <DSelect @options={{ITEMS}} @suppressFooter={{not (has-block "footer")}}>
    <:footer>
      {{~yield to="footer"~}}
    </:footer>
  </DSelect>
</template>;

module(
  "Integration | ui-kit | select | DSelect (@suppressFooter)",
  function (hooks) {
    setupRenderingTest(hooks);

    test("suppressFooter drops a passed footer", async function (assert) {
      await render(
        <template>
          <DSelect @options={{ITEMS}} @suppressFooter={{true}}>
            <:footer>
              <span class="test-footer">Footer</span>
            </:footer>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='listbox']").exists("the panel is open");
      assert.dom(".d-select__footer").doesNotExist("no footer region");
      assert.dom(".test-footer").doesNotExist("no footer content");
    });

    test("suppressFooter false keeps a passed footer", async function (assert) {
      await render(
        <template>
          <DSelect @options={{ITEMS}} @suppressFooter={{false}}>
            <:footer>
              <span class="test-footer">Footer</span>
            </:footer>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");

      assert.dom(".d-select__footer .test-footer").exists();
    });

    test("suppressFooter false never adds a footer that was not passed", async function (assert) {
      await render(
        <template>
          <DSelect @options={{ITEMS}} @suppressFooter={{false}} />
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='listbox']").exists("the panel is open");
      assert.dom(".d-select__footer").doesNotExist();
    });

    test("suppressFooter lets a forwarding recipe skip the footer its caller did not pass", async function (assert) {
      await render(<template><ForwardingSelect /></template>);
      await click("[role='combobox']");

      assert.dom("[role='listbox']").exists("the panel is open");
      assert
        .dom(".d-select__footer")
        .doesNotExist("no empty footer region below the list");
    });

    test("suppressFooter keeps a footer forwarded from the caller", async function (assert) {
      await render(
        <template>
          <ForwardingSelect>
            <:footer>
              <span class="test-footer">Footer</span>
            </:footer>
          </ForwardingSelect>
        </template>
      );
      await click("[role='combobox']");

      assert.dom(".d-select__footer .test-footer").exists();
    });
  }
);

module(
  "Integration | ui-kit | select | DSelect (:footer link)",
  function (hooks) {
    setupRenderingTest(hooks);

    /**
     * Resolves a theme color variable the way the browser paints it.
     *
     * @param {string} variable
     * @returns {string}
     */
    function themeColor(variable) {
      const probe = document.createElement("span");
      probe.style.color = `var(${variable})`;
      find(".d-select__footer").append(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    }

    test("a lone footer link sits at the trailing edge in the footer's muted link color", async function (assert) {
      await render(
        <template>
          <DSelect @options={{ITEMS}}>
            <:footer>
              <a class="test-footer-link" href="/settings">Settings</a>
            </:footer>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");

      const footer = find(".d-select__footer");
      const link = find(".test-footer-link");
      const style = getComputedStyle(footer);
      const scale = footer.getBoundingClientRect().width / footer.offsetWidth;
      const contentEnd =
        footer.getBoundingClientRect().right -
        (parseFloat(style.paddingRight) + parseFloat(style.borderRightWidth)) *
          scale;

      assert.true(
        Math.abs(link.getBoundingClientRect().right - contentEnd) < 1,
        `link ends at ${link.getBoundingClientRect().right} vs ${contentEnd}`
      );
      assert.strictEqual(
        getComputedStyle(link).color,
        themeColor("--primary-high")
      );
      assert.strictEqual(
        getComputedStyle(link).textDecorationLine,
        "none",
        "is not underlined at rest"
      );
    });

    test("a status note leads the footer and a link trails it", async function (assert) {
      await render(
        <template>
          <DSelect @options={{ITEMS}}>
            <:footer>
              <span class="test-footer-note">+19 more</span>
              <a class="test-footer-link" href="/all">View all</a>
            </:footer>
          </DSelect>
        </template>
      );
      await click("[role='combobox']");

      const footer = find(".d-select__footer").getBoundingClientRect();
      const note = find(".test-footer-note").getBoundingClientRect();
      const link = find(".test-footer-link").getBoundingClientRect();

      assert.true(
        note.left - footer.left < footer.right - note.right,
        "the note sits on the leading side"
      );
      assert.true(
        footer.right - link.right < link.left - footer.left,
        "the link sits on the trailing side"
      );
    });
  }
);
