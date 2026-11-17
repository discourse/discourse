import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DFloatingControlBar from "discourse/ui-kit/d-floating-control-bar";

const noop = () => {};

module("Integration | ui-kit | DFloatingControlBar", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the label and both controls", async function (assert) {
    await render(
      <template>
        <DFloatingControlBar
          @discardLabel="Discard"
          @label="You have unsaved changes"
          @onDiscard={{noop}}
          @onSave={{noop}}
          @saveLabel="Save"
        />
      </template>
    );

    assert
      .dom(".d-floating-control-bar__label")
      .hasText("You have unsaved changes");
    assert
      .dom(".d-floating-control-bar__controls .btn-primary")
      .hasText("Save");
    assert
      .dom(".d-floating-control-bar__controls .btn-default")
      .hasText("Discard");
  });

  test("escapes a plain string label", async function (assert) {
    const label = "<em>1</em> unsaved change";

    await render(
      <template>
        <DFloatingControlBar
          @discardLabel="Discard"
          @label={{label}}
          @onDiscard={{noop}}
          @onSave={{noop}}
          @saveLabel="Save"
        />
      </template>
    );

    assert.dom(".d-floating-control-bar__label em").doesNotExist();
    assert
      .dom(".d-floating-control-bar__label")
      .hasHtml("&lt;em&gt;1&lt;/em&gt; unsaved change");
  });

  test("renders a trusted label as markup", async function (assert) {
    await render(
      <template>
        <DFloatingControlBar
          @discardLabel="Discard"
          @label={{trustHTML "<em>1</em> unsaved change"}}
          @onDiscard={{noop}}
          @onSave={{noop}}
          @saveLabel="Save"
        />
      </template>
    );

    assert.dom(".d-floating-control-bar__label em").hasText("1");
  });

  test("marks the document while it is rendered, and stops when it is not", async function (assert) {
    const shown = tracked(false);

    await render(
      <template>
        {{#if shown.value}}
          <DFloatingControlBar
            @discardLabel="Discard"
            @label="Unsaved"
            @onDiscard={{noop}}
            @onSave={{noop}}
            @saveLabel="Save"
          />
        {{/if}}
      </template>
    );

    assert
      .dom(document.body)
      .doesNotHaveClass("d-floating-control-bar-visible");

    shown.value = true;
    await settled();

    assert.dom(document.body).hasClass("d-floating-control-bar-visible");

    shown.value = false;
    await settled();

    assert
      .dom(document.body)
      .doesNotHaveClass(
        "d-floating-control-bar-visible",
        "the reserved space is released with the bar"
      );
  });

  test("forwards attributes to the bar", async function (assert) {
    await render(
      <template>
        <DFloatingControlBar
          class="my-page__save-bar"
          data-test-bar="yes"
          @discardLabel="Discard"
          @label="Unsaved"
          @onDiscard={{noop}}
          @onSave={{noop}}
          @saveLabel="Save"
        />
      </template>
    );

    assert
      .dom(".d-floating-control-bar")
      .hasClass("my-page__save-bar", "a consumer class lands alongside its own")
      .hasAttribute(
        "data-test-bar",
        "yes",
        "and arbitrary attributes reach it"
      );
  });

  test("gives the save button the requested id", async function (assert) {
    await render(
      <template>
        <DFloatingControlBar
          @discardLabel="Discard"
          @label="Unsaved"
          @onDiscard={{noop}}
          @onSave={{noop}}
          @saveButtonId="save-thing"
          @saveLabel="Save"
        />
      </template>
    );

    assert.dom("#save-thing").hasClass("btn-primary");
  });

  test("disables discard and shows the save button loading while saving", async function (assert) {
    let resolveSave;
    const save = () => new Promise((resolve) => (resolveSave = resolve));

    await render(
      <template>
        <DFloatingControlBar
          @discardLabel="Discard"
          @label="Unsaved"
          @onDiscard={{noop}}
          @onSave={{save}}
          @saveLabel="Save"
        />
      </template>
    );

    document.querySelector(".d-floating-control-bar .btn-primary").click();
    await waitUntil(() =>
      document.querySelector(".d-floating-control-bar .btn-primary.is-loading")
    );

    assert
      .dom(".d-floating-control-bar .btn-default")
      .isDisabled("discard is unavailable mid-save");

    resolveSave();
    await settled();

    assert
      .dom(".d-floating-control-bar .btn-default")
      .isNotDisabled("and available again once the save settles");
  });

  test("lifts itself above the footer nav when one is showing", async function (assert) {
    document.documentElement.classList.add("footer-nav-visible");

    try {
      await render(
        <template>
          <DFloatingControlBar
            @discardLabel="Discard"
            @label="Unsaved"
            @onDiscard={{noop}}
            @onSave={{noop}}
            @saveLabel="Save"
          />
        </template>
      );

      // --footer-nav-height (49px) + env(safe-area-inset-bottom) (0 here) +
      // --space-4 (16px).
      assert.dom(".d-floating-control-bar").hasStyle({ bottom: "65px" });
    } finally {
      document.documentElement.classList.remove("footer-nav-visible");
    }
  });

  test("lets a page override outrank the kit's own footer-nav offset", async function (assert) {
    document.documentElement.classList.add("footer-nav-visible");

    try {
      await render(
        <template>
          <div class="edit-category-page">
            <DFloatingControlBar
              @discardLabel="Discard"
              @label="Unsaved"
              @onDiscard={{noop}}
              @onSave={{noop}}
              @saveLabel="Save"
            />
          </div>
        </template>
      );

      // The page's own offset, not the kit's 65px: the ui-kit stylesheet is
      // imported first, so a page override of equal specificity has to win.
      // --footer-nav-height (49px) + inset (0) + --powered-by-height (0) +
      // --space-5 (20px).
      assert
        .dom(".d-floating-control-bar")
        .hasStyle(
          { bottom: "69px" },
          "the page override still lands after the kit's base rule"
        );
    } finally {
      document.documentElement.classList.remove("footer-nav-visible");
    }
  });

  test("spans the element it was rendered into", async function (assert) {
    await render(
      <template>
        <div class="host" style="width: 480px">
          <DFloatingControlBar
            @discardLabel="Discard"
            @label="Unsaved"
            @onDiscard={{noop}}
            @onSave={{noop}}
            @saveLabel="Save"
          />
        </div>
      </template>
    );

    assert.dom(".d-floating-control-bar").hasStyle({ width: "480px" });
  });

  test("matches an explicit width source over its parent", async function (assert) {
    const source = document.createElement("div");
    source.style.width = "640px";
    document.getElementById("ember-testing").appendChild(source);

    try {
      await render(
        <template>
          <div class="host" style="width: 480px">
            <DFloatingControlBar
              @discardLabel="Discard"
              @label="Unsaved"
              @onDiscard={{noop}}
              @onSave={{noop}}
              @saveLabel="Save"
              @widthSource={{source}}
            />
          </div>
        </template>
      );

      assert.dom(".d-floating-control-bar").hasStyle({ width: "640px" });
    } finally {
      source.remove();
    }
  });

  test("follows the width source when the source alone resizes", async function (assert) {
    const source = document.createElement("div");
    source.style.width = "640px";
    document.getElementById("ember-testing").appendChild(source);

    try {
      await render(
        <template>
          <DFloatingControlBar
            @discardLabel="Discard"
            @label="Unsaved"
            @onDiscard={{noop}}
            @onSave={{noop}}
            @saveLabel="Save"
            @widthSource={{source}}
          />
        </template>
      );

      // Deliberately no window resize: the page column changes width on its own
      // when the sidebar opens, and a `resize` listener never hears about it.
      source.style.width = "420px";

      await waitUntil(
        () =>
          document.querySelector(".d-floating-control-bar").style.width ===
          "420px",
        { timeout: 2000 }
      );

      assert.dom(".d-floating-control-bar").hasStyle({ width: "420px" });
    } finally {
      source.remove();
    }
  });
});
