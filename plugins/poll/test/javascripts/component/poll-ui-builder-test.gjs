import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import PollUiBuilder from "discourse/plugins/poll/discourse/components/modal/poll-ui-builder";

async function setupBuilder(poll) {
  const noop = () => {};
  const results = [];
  const model = {
    toolbarEvent: { getText: () => "", addText: (t) => results.push(t) },
    poll,
    onSave: poll ? (text) => results.push(text) : undefined,
  };

  await render(
    <template>
      <PollUiBuilder @inline={{true}} @model={{model}} @closeModal={{noop}} />
    </template>
  );

  return results;
}

module("Component | PollUiBuilder", function (hooks) {
  setupRenderingTest(hooks);

  test("editing preserves groups, close date, and attributes outside the builder", async function (assert) {
    const results = await setupBuilder({
      name: "existing",
      type: "regular",
      options: ["First", "Second"],
      public: "false",
      groups: "custom_group",
      close: "2050-01-01T12:00:00.000Z",
      status: "closed",
      order: "desc",
    });

    assert
      .dom(".poll-option-value input")
      .exists({ count: 2 }, "editing opens in simple mode");
    assert.dom(".poll-title").doesNotExist("advanced fields start hidden");
    await click(".advanced-mode-btn");
    await fillIn(".poll-title textarea", "New title");
    await click(".insert-poll");

    assert.strictEqual(
      results[0],
      "[poll name=existing type=regular results=always public=false chartType=bar groups=custom_group close=2050-01-01T12:00:00.000Z status=closed order=desc]\n# New title\n* First\n* Second\n[/poll]\n",
      "saves the edited poll without losing its settings or identity"
    );
  });

  test("editing preserves date-only close values and structured content", async function (assert) {
    const results = await setupBuilder({
      type: "regular",
      title: "First line\nSecond line",
      options: ["First paragraph\n\nSecond paragraph", "Simple"],
      close: "2050-01-01",
    });

    assert
      .dom(".poll-title textarea")
      .hasValue(
        "First line\nSecond line",
        "structured polls open in advanced mode without flattening the title"
      );
    await click(".insert-poll");

    assert.strictEqual(
      results[0],
      "[poll type=regular results=always public=false chartType=bar close=2050-01-01]\n# First line<br>Second line\n* First paragraph\n\n  Second paragraph\n* Simple\n[/poll]\n",
      "does not shift the close time or detach option content"
    );
  });

  test("editing structured options in advanced mode preserves nesting", async function (assert) {
    const results = await setupBuilder({
      type: "regular",
      options: ["Parent\n\n* Child\n  * Grandchild", "Simple"],
    });

    assert
      .dom(".poll-options textarea")
      .hasValue(
        "Parent\n\n  * Child\n    * Grandchild\nSimple",
        "shows continuation content indented beneath its option"
      );
    await fillIn(
      ".poll-options textarea",
      "Updated parent\n\n  * Child\n    * Grandchild\nSimple"
    );
    await click(".insert-poll");

    assert.strictEqual(
      results[0],
      "[poll type=regular results=always public=false chartType=bar]\n* Updated parent\n\n  * Child\n    * Grandchild\n* Simple\n[/poll]\n",
      "keeps nested content inside the edited option"
    );
  });

  test("Can switch poll type", async function (assert) {
    await setupBuilder();

    assert.dom(".poll-type-value-regular").hasClass("active");

    await click(".poll-type-value-multiple");
    assert
      .dom(".poll-type-value-multiple")
      .hasClass("active", "can switch to 'multiple' type");

    assert
      .dom(".poll-type-value-number")
      .doesNotExist("number type is hidden by default");

    await click(".advanced-mode-btn");
    assert
      .dom(".poll-type-value-number")
      .exists("number type appears in advanced mode");

    await click(".poll-type-value-number");
    assert
      .dom(".poll-type-value-number")
      .hasClass("active", "can switch to 'number' type");
  });

  test("Automatically updates min/max when number of options change", async function (assert) {
    await setupBuilder();

    await click(".poll-type-value-multiple");
    assert.dom(".poll-options-min").hasValue("0");
    assert.dom(".poll-options-max").hasValue("0");

    await fillIn(".poll-option-value input", "a");
    assert.dom(".poll-options-min").hasValue("1");
    assert.dom(".poll-options-max").hasValue("1");

    await click(".poll-option-add");

    await fillIn(".poll-option-value:nth-of-type(2) input", "b");
    assert.dom(".poll-options-min").hasValue("1");
    assert.dom(".poll-options-max").hasValue("2");
  });

  test("disables save button", async function (assert) {
    this.siteSettings.poll_maximum_options = 3;

    await setupBuilder();
    assert
      .dom(".insert-poll")
      .isDisabled("Insert button disabled when no options specified");

    await fillIn(".poll-option-value input", "   ");
    assert
      .dom(".insert-poll")
      .isDisabled("Insert button disabled for a whitespace-only option");

    await fillIn(".poll-option-value input", "a");
    assert
      .dom(".insert-poll")
      .isEnabled("Insert button enabled once an option is specified");

    await click(".poll-option-add");
    await fillIn(".poll-option-value:nth-of-type(2) input", "b");
    await click(".poll-option-add");
    await fillIn(".poll-option-value:nth-of-type(3) input", "c");
    await click(".poll-option-add");
    await fillIn(".poll-option-value:nth-of-type(4) input", "d");

    assert
      .dom(".insert-poll")
      .isDisabled("Insert button disabled when too many options");
  });

  test("number mode", async function (assert) {
    const results = await setupBuilder();

    await click(".advanced-mode-btn");
    await click(".poll-type-value-number");

    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=number results=always min=1 max=20 step=1 public=true]\n[/poll]\n"
    );

    await fillIn(".poll-options-step", "2");
    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=number results=always min=1 max=20 step=2 public=true]\n[/poll]\n",
      "includes step value"
    );

    await click(".poll-toggle-public");
    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=number results=always min=1 max=20 step=2 public=false]\n[/poll]\n",
      "can be set to private"
    );

    await fillIn(".poll-options-step", "0");
    assert
      .dom(".insert-poll")
      .isDisabled("Insert button disabled when step is 0");
  });

  test("regular mode", async function (assert) {
    const results = await setupBuilder();

    await fillIn(".poll-option-value input", "a");
    await click(".poll-option-add");
    await fillIn(".poll-option-value:nth-of-type(2) input", "b");

    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=regular results=always public=true chartType=bar]\n* a\n* b\n[/poll]\n",
      "has correct output"
    );

    await click(".advanced-mode-btn");

    await click(".poll-toggle-public");

    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=regular results=always public=false chartType=bar]\n* a\n* b\n[/poll]\n",
      "can be set to private"
    );

    await click(".poll-toggle-dynamic");
    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=regular results=always public=false chartType=bar dynamic=true]\n* a\n* b\n[/poll]\n",
      "includes dynamic=true when enabled"
    );

    await click(".poll-toggle-dynamic");
    const groupChooser = selectKit(".group-chooser");
    await groupChooser.expand();
    await groupChooser.selectRowByName("custom_group");
    await groupChooser.collapse();

    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=regular results=always public=false chartType=bar groups=custom_group]\n* a\n* b\n[/poll]\n",
      "has groups"
    );
  });

  test("multi-choice mode", async function (assert) {
    const results = await setupBuilder();

    await click(".poll-type-value-multiple");

    await fillIn(".poll-option-value input", "a");
    await click(".poll-option-add");
    await fillIn(".poll-option-value:nth-of-type(2) input", "b");

    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=multiple results=always min=1 max=2 public=true chartType=bar]\n* a\n* b\n[/poll]\n",
      "has correct output"
    );

    await click(".advanced-mode-btn");

    await click(".poll-toggle-public");

    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=multiple results=always min=1 max=2 public=false chartType=bar]\n* a\n* b\n[/poll]\n",
      "can be set to private boolean"
    );
  });

  test("staff_only option is not present for non-staff", async function (assert) {
    await setupBuilder();

    await click(".advanced-mode-btn");
    const resultVisibility = selectKit(".poll-result");

    assert.strictEqual(resultVisibility.header().value(), "always");

    await resultVisibility.expand();
    assert.false(
      resultVisibility.rowByValue("staff_only").exists(),
      "staff_only is not visible to normal users"
    );
    await resultVisibility.collapse();

    this.currentUser.setProperties({ admin: true });

    await resultVisibility.expand();
    assert.true(
      resultVisibility.rowByValue("staff_only").exists(),
      "staff_only is visible to staff"
    );
    await resultVisibility.collapse();
  });

  test("default public value can be controlled with site setting", async function (assert) {
    this.siteSettings.poll_default_public = false;

    const results = await setupBuilder();

    await fillIn(".poll-option-value input", "a");
    await click(".poll-option-add");
    await fillIn(".poll-option-value:nth-of-type(2) input", "b");

    await click(".insert-poll");

    assert.strictEqual(
      results[results.length - 1],
      "[poll type=regular results=always public=false chartType=bar]\n* a\n* b\n[/poll]\n",
      "can be set to private boolean"
    );
  });
});
