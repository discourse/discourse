import { tracked } from "@glimmer/tracking";
import { click, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ExpressionWrapper from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/expression-wrapper";
import { WORKFLOW_VARIABLE_MIME } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-context";

function variableTransfer(variable) {
  const dropText = `{{ $json.${variable.id} }}`;
  return {
    types: [WORKFLOW_VARIABLE_MIME, "text/plain"],
    getData: (type) => {
      if (type === WORKFLOW_VARIABLE_MIME) {
        return JSON.stringify({ ...variable, dropText });
      }
      return type === "text/plain" ? dropText : "";
    },
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

    test("preserves plain text when dropping a variable into a text control", async function (assert) {
      const originalValue = "Introduction 😀\n\nالخلاصة";
      const insertionStart = "Introduction 😀\n".length;
      this.field = new TestField(originalValue);
      this.schema = { type: "string" };

      await render(
        <template>
          <ExpressionWrapper
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{true}}
            @preserveTextareaOnDrop={{true}}
          >
            <textarea
              class="plain-control"
              value={{this.field.value}}
            ></textarea>
          </ExpressionWrapper>
        </template>
      );

      const textareaElement = find(".plain-control");
      const dropText = "{{ $json.result }}";

      await triggerEvent(textareaElement, "dragover", {
        dataTransfer: variableTransfer({ id: "result" }),
      });

      assert.strictEqual(
        this.field.value,
        originalValue,
        "dragging over the field does not change its value"
      );

      await triggerEvent(textareaElement, "drop", {
        dataTransfer: variableTransfer({ id: "result" }),
      });
      textareaElement.value = `Introduction 😀\n${dropText}\nالخلاصة`;
      textareaElement.setSelectionRange(
        insertionStart,
        insertionStart + dropText.length
      );
      await triggerEvent(textareaElement, "input", {
        data: dropText,
        inputType: "insertFromDrop",
      });

      assert.strictEqual(
        this.field.value,
        "=Introduction 😀\n{{ $json.result }}\nالخلاصة",
        "the original text is preserved around the expression"
      );
      assert
        .dom(".workflows-variable-input")
        .exists("the field switches to dynamic mode");
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
