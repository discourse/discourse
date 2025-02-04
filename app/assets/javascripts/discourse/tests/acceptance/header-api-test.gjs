import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

// TODO: Consolidate these tests into a single acceptance test once the Glimmer
// header is the default.

acceptance("Header API - anonymous", function () {
  test("can add buttons to the header", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerButtons.add("test", <template>
        <button class="test-button">Test</button>
      </template>);
    });

    await visit("/");
    assert.dom("button.test-button").exists("button is displayed");
  });

  test("buttons are positioned to the left of the auth buttons by default", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerButtons.add("test", <template>
        <button class="test-button">Test</button>
      </template>);
    });

    await visit("/");
    const testButton = document.querySelector(".test-button");
    const authButtons = document.querySelector(".auth-buttons");
    assert.strictEqual(
      testButton.compareDocumentPosition(authButtons),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "Test button is positioned before auth-buttons"
    );
  });

  test("can add icons to the header", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerIcons.add("test", <template>
        <span class="test-icon">Test</span>
      </template>);
    });

    await visit("/");
    assert.dom(".test-icon").exists("icon is displayed");
  });

  test("icons are positioned to the left of search icon by default", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerIcons.add("test", <template>
        <span class="test-icon">Test</span>
      </template>);
    });

    await visit("/");
    const testIcon = document.querySelector(".test-icon");
    const search = document.querySelector(".search-dropdown");
    assert.strictEqual(
      testIcon.compareDocumentPosition(search),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "Test icon is positioned before search icon"
    );
  });
});

acceptance("Glimmer Header API - authenticated", function (needs) {
  needs.user({ groups: AUTO_GROUPS.everyone });

  test("can add buttons to the header", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerButtons.add("test", <template>
        <button class="test-button">Test</button>
      </template>);
    });

    await visit("/");
    assert.dom("button.test-button").exists("button is displayed");
  });

  test("buttons can be repositioned", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerButtons.add("test1", <template>
        <button class="test1-button">Test1</button>
      </template>);

      api.headerButtons.add(
        "test2",
        <template><button class="test2-button">Test2</button></template>,
        { before: "test1" }
      );
    });

    await visit("/");
    const test1 = document.querySelector(".test1-button");
    const test2 = document.querySelector(".test2-button");
    assert.strictEqual(
      test2.compareDocumentPosition(test1),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "Test2 button is positioned before Test1 button"
    );
  });

  test("can add icons to the header", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerIcons.add("test", <template>
        <span class="test-icon">Test</span>
      </template>);
    });

    await visit("/");
    assert.dom(".test-icon").exists("icon is displayed");
  });

  test("icons can be repositioned", async function (assert) {
    withPluginApi("1.29.0", (api) => {
      api.headerIcons.add("test1", <template>
        <span class="test1-icon">Test1</span>
      </template>);

      api.headerIcons.add(
        "test2",
        <template><span class="test2-icon">Test2</span></template>,
        { before: "test1" }
      );
    });

    await visit("/");
    const test1 = document.querySelector(".test1-icon");
    const test2 = document.querySelector(".test2-icon");
    assert.strictEqual(
      test2.compareDocumentPosition(test1),
      Node.DOCUMENT_POSITION_FOLLOWING,
      "Test2 icon is positioned before Test1 icon"
    );
  });
});
