import { tracked } from "@glimmer/tracking";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import ExpressionWrapper from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/expression-wrapper";

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
