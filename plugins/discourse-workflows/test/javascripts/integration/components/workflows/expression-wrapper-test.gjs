import { tracked } from "@glimmer/tracking";
import { click, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import DefaultInputControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/default-input-control";
import ExpressionWrapper from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/expression-wrapper";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

function variableTransfer(variable) {
  return {
    types: [WORKFLOW_VARIABLE_MIME],
    getData: (type) =>
      type === WORKFLOW_VARIABLE_MIME ? JSON.stringify(variable) : "",
  };
}

class TestField {
  @tracked value;

  constructor(value) {
    this.value = value;
  }

  set(newValue) {
    this.value = newValue;
  }
}

module(
  "Integration | Component | Workflows | ExpressionWrapper",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response(200, { variables: [] })
      );
    });

    hooks.afterEach(function () {
      sinon.restore();
    });

    test("preserves plain text when dropping a variable into a text control", async function (assert) {
      const originalValue = "Introduction 😀\n\nالخلاصة";
      const insertionStart = "Introduction 😀\n".length;
      this.configuration = { prompt: originalValue };
      this.schema = { type: "string" };

      await render(
        <template>
          <Form @data={{this.configuration}} as |form transientData|>
            <form.Field
              @name="prompt"
              @title="Prompt"
              @type="textarea"
              as |field|
            >
              <DefaultInputControl
                @field={{field}}
                @schema={{this.schema}}
                @supportsExpression={{true}}
              />
            </form.Field>
            <output data-value={{transientData.prompt}}></output>
          </Form>
        </template>
      );

      const textareaElement = find("textarea");
      sinon.stub(document, "caretPositionFromPoint").returns({
        offsetNode: textareaElement,
        offset: insertionStart,
      });

      await triggerEvent(textareaElement, "dragover", {
        dataTransfer: variableTransfer({ id: "result" }),
        clientX: 20,
        clientY: 30,
      });

      assert.strictEqual(
        find("output").dataset.value,
        originalValue,
        "dragging over the field does not change its value"
      );

      await triggerEvent(textareaElement, "drop", {
        dataTransfer: variableTransfer({ id: "result" }),
        clientX: 20,
        clientY: 30,
      });

      assert.strictEqual(
        find("output").dataset.value,
        "=Introduction 😀\n{{ $json.result }}\nالخلاصة",
        "the original text is preserved around the expression"
      );
      assert
        .dom(".workflows-variable-input")
        .exists("the field switches to dynamic mode");
    });

    test("appends a variable when dropping on the mode control", async function (assert) {
      this.field = new TestField("Existing prompt");
      this.schema = { type: "string" };

      await render(
        <template>
          <ExpressionWrapper
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{true}}
          >
            <textarea value={{this.field.value}}></textarea>
          </ExpressionWrapper>
        </template>
      );

      const modeControl = find(".workflows-property-engine__mode-control");
      sinon.stub(document, "caretPositionFromPoint").returns({
        offsetNode: modeControl,
        offset: 0,
      });

      await triggerEvent(modeControl, "drop", {
        dataTransfer: variableTransfer({ id: "result" }),
        clientX: 20,
        clientY: 30,
      });

      assert.strictEqual(
        this.field.value,
        "=Existing prompt{{ $json.result }}",
        "dropping outside the text control preserves and appends to its value"
      );
    });

    test("preserves populated single-line text controls", async function (assert) {
      this.field = new TestField("Existing title");
      this.schema = { type: "string" };

      await render(
        <template>
          <ExpressionWrapper
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{true}}
          >
            <input type="text" value={{this.field.value}} />
          </ExpressionWrapper>
        </template>
      );

      const inputElement = find("input[type='text']");
      sinon.stub(document, "caretPositionFromPoint").returns({
        offsetNode: inputElement,
        offset: 9,
      });

      await triggerEvent(inputElement, "drop", {
        dataTransfer: variableTransfer({ id: "result" }),
        clientX: 20,
        clientY: 30,
      });

      assert.strictEqual(
        this.field.value,
        "=Existing {{ $json.result }}title",
        "the expression is inserted without replacing the current title"
      );
    });

    test("keeps replacement behavior for string-valued non-text controls", async function (assert) {
      this.field = new TestField("first");
      this.schema = { type: "string" };

      await render(
        <template>
          <ExpressionWrapper
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{true}}
          >
            <select class="plain-control">
              <option value="first">First</option>
            </select>
          </ExpressionWrapper>
        </template>
      );

      await triggerEvent(".plain-control", "dragover", {
        dataTransfer: variableTransfer({ id: "result" }),
      });
      await triggerEvent(".plain-control", "drop", {
        dataTransfer: variableTransfer({ id: "result" }),
      });

      assert.strictEqual(
        this.field.value,
        "={{ $json.result }}",
        "the selected value is replaced by the expression"
      );
    });

    test("converts fixed arrays to whole expressions", async function (assert) {
      this.field = new TestField(["sam", "alice"]);
      this.schema = { type: "array" };

      await render(
        <template>
          <ExpressionWrapper
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{true}}
          >
            <div class="plain-control"></div>
          </ExpressionWrapper>
        </template>
      );

      await click(
        '.workflows-property-engine__mode-control input[value="dynamic"]'
      );

      assert.strictEqual(
        this.field.value,
        '={{ ["sam","alice"] }}',
        "the dynamic value preserves the array type"
      );
    });

    test("converts comma-separated dynamic values to fixed arrays", async function (assert) {
      this.field = new TestField("=sam,alice");
      this.schema = { type: "array" };

      await render(
        <template>
          <ExpressionWrapper
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{true}}
          >
            <div class="plain-control"></div>
          </ExpressionWrapper>
        </template>
      );

      await click(
        '.workflows-property-engine__mode-control input[value="plain"]'
      );

      assert.deepEqual(
        this.field.value,
        ["sam", "alice"],
        "the fixed value is converted to an array"
      );
    });

    test("converts dynamic array literals to fixed arrays", async function (assert) {
      this.field = new TestField('={{ ["sam","alice"] }}');
      this.schema = { type: "array" };

      await render(
        <template>
          <ExpressionWrapper
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{true}}
          >
            <div class="plain-control"></div>
          </ExpressionWrapper>
        </template>
      );

      await click(
        '.workflows-property-engine__mode-control input[value="plain"]'
      );

      assert.deepEqual(
        this.field.value,
        ["sam", "alice"],
        "the dynamic array literal is converted to an array"
      );
    });
  }
);
