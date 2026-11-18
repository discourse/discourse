import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DTableHeaderToggle from "discourse/ui-kit/d-table-header-toggle";
import I18n, { i18n } from "discourse-i18n";

module("Integration | ui-kit | DTableHeaderToggle", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    I18n.translations[I18n.locale].js.test_toggle = {
      name: "Name",
      name_long: "Full name",
      plain: "Plain",
    };
  });

  test("prefers the long form of @labelKey with @automatic", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle
          @automatic={{true}}
          @field="name"
          @labelKey="test_toggle.name"
        />
      </template>
    );

    assert.dom(".header-contents .text").hasText("Full name");
    assert
      .dom(".header-contents")
      .hasAttribute(
        "aria-label",
        i18n("directory.sort.label", { criteria: "Full name" }),
        "the accessible name describes the sort"
      );
  });

  test("falls back to @labelKey without a long form", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle
          @automatic={{true}}
          @field="plain"
          @labelKey="test_toggle.plain"
        />
      </template>
    );

    assert.dom(".header-contents .text").hasText("Plain");
  });

  test("uses @field as the key without @automatic", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle
          @field="test_toggle.name"
          @labelKey="test_toggle.plain"
        />
      </template>
    );

    assert.dom(".header-contents .text").hasText("Full name");
  });

  test("shows @field as given with @translated", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle @field="Favorite color" @translated={{true}} />
      </template>
    );

    assert.dom(".header-contents .text").hasText("Favorite color");
    assert
      .dom(".header-contents")
      .hasAttribute(
        "id",
        "table-header-toggle-Favoritecolor",
        "the id drops the whitespace of @field"
      )
      .hasAttribute(
        "aria-label",
        i18n("directory.sort.label", { criteria: "Favorite color" })
      );
  });

  test("reflects an ascending sort on @field", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle
          @asc={{true}}
          @field="name"
          @order="name"
          @translated={{true}}
        />
      </template>
    );

    assert
      .dom(".directory-table__column-header")
      .hasAttribute("aria-sort", "ascending");
    assert.dom(".header-contents").hasAttribute("aria-pressed", "mixed");
    assert.dom(".d-icon-chevron-up").exists("an up chevron is shown");
  });

  test("reflects a descending sort on @field", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle @field="name" @order="name" @translated={{true}} />
      </template>
    );

    assert
      .dom(".directory-table__column-header")
      .hasAttribute("aria-sort", "descending");
    assert.dom(".header-contents").hasAttribute("aria-pressed", "true");
    assert.dom(".d-icon-chevron-down").exists("a down chevron is shown");
  });

  test("shows no sort when another column is sorted", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle
          @asc={{true}}
          @field="name"
          @order="email"
          @translated={{true}}
        />
      </template>
    );

    assert
      .dom(".directory-table__column-header")
      .hasAttribute("aria-sort", "none");
    assert.dom(".header-contents").hasAttribute("aria-pressed", "false");
    assert.dom(".d-icon").doesNotExist("no chevron is shown");
  });

  test("toggles the sort on click and keeps the focus", async function (assert) {
    const calls = [];
    const onToggle = (field, asc) => calls.push([field, asc]);

    await render(
      <template>
        <DTableHeaderToggle
          @field="name"
          @onToggle={{onToggle}}
          @order="name"
          @translated={{true}}
        />
      </template>
    );
    await click(".directory-table__column-header");

    assert.deepEqual(
      calls,
      [["name", true]],
      "a descending column switches to ascending"
    );
    assert
      .dom(".header-contents")
      .isFocused("the header keeps the focus after the toggle");
  });

  test("resets the direction when sorting a new column", async function (assert) {
    const calls = [];
    const onToggle = (field, asc) => calls.push([field, asc]);

    await render(
      <template>
        <DTableHeaderToggle
          @asc={{true}}
          @field="name"
          @onToggle={{onToggle}}
          @order="name"
          @translated={{true}}
        />
      </template>
    );
    await click(".directory-table__column-header");

    assert.deepEqual(calls, [["name", null]], "the direction is cleared");
  });

  test("toggles the sort on Enter", async function (assert) {
    const calls = [];
    const onToggle = (field, asc) => calls.push([field, asc]);

    await render(
      <template>
        <DTableHeaderToggle
          @field="name"
          @onToggle={{onToggle}}
          @order="email"
          @translated={{true}}
        />
      </template>
    );
    await triggerKeyEvent(".directory-table__column-header", "keypress", "A");
    await triggerKeyEvent(
      ".directory-table__column-header",
      "keypress",
      "Enter"
    );

    assert.deepEqual(calls, [["name", null]], "only Enter toggles");
  });

  test("names the likes criteria for the heart @icon", async function (assert) {
    await render(
      <template>
        <DTableHeaderToggle
          class="likes"
          @automatic={{true}}
          @field="likes"
          @icon="heart"
          @labelKey="test_toggle.plain"
        />
      </template>
    );

    assert.dom(".likes .d-icon-heart").exists("the icon is shown");
    assert.dom(".header-contents").hasAttribute(
      "aria-label",
      i18n("directory.sort.label", {
        criteria: `${i18n("likes_lowercase", { count: 2 })} Plain`,
      })
    );
  });
});
