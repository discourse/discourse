import { render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import VariableInput from "discourse/plugins/discourse-workflows/admin/components/workflows/variable/input";

module("Integration | Component | workflows/variable/input", function (hooks) {
  setupRenderingTest(hooks);

  test("renders existing expression value as pills", async function (assert) {
    const value = "Hello {{ $current_user.username }}!";

    await render(<template><VariableInput @value={{value}} /></template>);

    const pills = this.element.querySelectorAll(".workflows-variable-pill");
    assert.strictEqual(pills.length, 1);
    assert.strictEqual(pills[0].textContent.trim(), "$current_user.username");
  });

  test("renders multiple pills in a value", async function (assert) {
    const value = "{{ $execution.id }} - {{ $json.title }}";

    await render(<template><VariableInput @value={{value}} /></template>);

    const pills = this.element.querySelectorAll(".workflows-variable-pill");
    assert.strictEqual(pills.length, 2);
    assert.strictEqual(pills[0].textContent.trim(), "$execution.id");
    assert.strictEqual(pills[1].textContent.trim(), "$json.title");
  });

  test("drop with $ prefix keeps variable id as-is", async function (assert) {
    let captured = null;
    const onChange = (val) => (captured = val);

    await render(
      <template><VariableInput @value="" @onChange={{onChange}} /></template>
    );

    const editor = this.element.querySelector(".workflows-variable-input");

    const dataTransfer = new DataTransfer();
    dataTransfer.setData(
      "application/x-workflow-variable",
      JSON.stringify({
        id: "$current_user.username",
        key: "username",
        type: "string",
      })
    );

    await triggerEvent(editor, "drop", { dataTransfer });

    assert.true(
      captured.includes("{{ $current_user.username }}"),
      `serialized value "${captured}" includes $current_user.username`
    );
  });

  test("drop without $ prefix adds $json. prefix", async function (assert) {
    let captured = null;
    const onChange = (val) => (captured = val);

    await render(
      <template><VariableInput @value="" @onChange={{onChange}} /></template>
    );

    const editor = this.element.querySelector(".workflows-variable-input");

    const dataTransfer = new DataTransfer();
    dataTransfer.setData(
      "application/x-workflow-variable",
      JSON.stringify({
        id: "topic_id",
        key: "topic_id",
        type: "integer",
      })
    );

    await triggerEvent(editor, "drop", { dataTransfer });

    assert.true(
      captured.includes("{{ $json.topic_id }}"),
      `serialized value "${captured}" includes $json.topic_id`
    );
  });

  test("serializes pills back to expression format", async function (assert) {
    let captured = null;
    const onChange = (val) => (captured = val);
    const value = "prefix {{ $vars.API_URL }} suffix";

    await render(
      <template>
        <VariableInput @value={{value}} @onChange={{onChange}} />
      </template>
    );

    const editor = this.element.querySelector(".workflows-variable-input");
    await triggerEvent(editor, "input");

    assert.strictEqual(captured, "prefix {{ $vars.API_URL }} suffix");
  });
});
