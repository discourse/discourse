import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Content from "discourse/components/composer-picker/content";
import { resetComposerPickerTabs } from "discourse/lib/composer-picker";
import emojisFixtures from "discourse/tests/fixtures/emojis-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";

module("Integration | Component | ComposerPickerContent", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis.json", () =>
      response(emojisFixtures["/emojis.json"])
    );
    pretender.get("/emojis/search-aliases.json", () => response([]));
    pretender.get("/gifs/categories.json", () => response({ tags: [] }));
    pretender.get("/gifs/search.json", () =>
      response({ results: [], next: "" })
    );

    this.siteSettings.enable_emoji = true;
    this.siteSettings.enable_gifs = true;

    // Don't let a remembered tab from another test leak in.
    this.owner
      .lookup("service:key-value-store")
      .remove("composer_picker_last_tab");
  });

  hooks.afterEach(function () {
    resetComposerPickerTabs();
    this.owner.lookup("service:emoji-store").diversity = 1;
  });

  test("renders a tab for each enabled tab", async function (assert) {
    await render(<template><Content @context="topic" /></template>);

    assert.dom(".composer-picker__tabs").exists("the tab bar is shown");
    assert
      .dom(".composer-picker__tab")
      .exists({ count: 2 }, "one button per enabled tab");
    assert
      .dom(".composer-picker__tab.--active")
      .exists({ count: 1 }, "exactly one tab is active");
    assert.dom(".emoji-picker").exists("the emoji tab is active by default");
  });

  test("hides the tab bar when only one tab is enabled", async function (assert) {
    this.siteSettings.enable_gifs = false;

    await render(<template><Content @context="topic" /></template>);

    assert
      .dom(".composer-picker__tabs")
      .doesNotExist("no tab bar with a single tab");
    assert.dom(".emoji-picker").exists("the lone emoji panel is rendered");
  });

  test("switching to the GIFs tab renders the GIF panel", async function (assert) {
    await render(<template><Content @context="topic" /></template>);

    await click(".composer-picker__tab:last-child");

    assert
      .dom(".gif-panel__input input")
      .exists("the GIF search panel is shown");
    assert
      .dom(".emoji-picker")
      .doesNotExist("the emoji panel is no longer rendered");
  });

  test("forwards a selection with the value and originating tab", async function (assert) {
    const selections = [];
    const onSelect = (value, tab) => selections.push({ value, tab: tab.id });

    await render(
      <template><Content @context="topic" @onSelect={{onSelect}} /></template>
    );

    await emojiPicker(".emoji-picker").select("grinning");

    assert.deepEqual(
      selections,
      [{ value: "grinning", tab: "emoji" }],
      "onSelect receives the emoji code and the emoji tab"
    );
  });
});
