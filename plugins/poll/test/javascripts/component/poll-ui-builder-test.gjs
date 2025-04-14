import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import PollUiBuilder from "discourse/plugins/poll/discourse/components/modal/poll-ui-builder";

async function setupBuilder() {
  const noop = () => {};
  const results = [];
  const model = {
    toolbarEvent: { getText: () => "", addText: (t) => results.push(t) },
  };

  await render(
    <template>
      <PollUiBuilder @inline={{true}} @model={{model}} @closeModal={{noop}} />
    </template>
  );

  return results;
}

module("Poll | Component | poll-ui-builder", function (hooks) {
  setupRenderingTest(hooks);

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

    await click(".show-advanced");
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

    await click(".show-advanced");
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

    await click(".show-advanced");

    await click(".poll-toggle-public");

    await click(".insert-poll");
    assert.strictEqual(
      results[results.length - 1],
      "[poll type=regular results=always public=false chartType=bar]\n* a\n* b\n[/poll]\n",
      "can be set to private"
    );

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

    await click(".show-advanced");

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

    await click(".show-advanced");
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
