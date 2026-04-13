import { get, hash } from "@ember/helper";
import { focus, render, typeIn } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function getFieldMeta() {
  return {
    region: { type: "text" },
    name: { type: "text" },
  };
}

function fieldType(type) {
  return type === "checkbox" ? "checkbox" : "input";
}

function fieldKeys(obj) {
  return obj ? Object.keys(obj) : [];
}

module(
  "Integration | Component | FormKit | Object | Focus retention",
  function (hooks) {
    setupRenderingTest(hooks);

    test("retains focus when @type depends on yielded data inside form.Object", async function (assert) {
      await render(
        <template>
          <Form
            @data={{hash
              provider="aws_bedrock"
              params=(hash region="" name="test")
            }}
            as |form data|
          >
            <form.Object @name="params" as |object objectData|>
              {{#each (fieldKeys objectData) as |key|}}
                {{#let (get (getFieldMeta data.provider) key) as |params|}}
                  <object.Field
                    @type={{fieldType params.type}}
                    @name={{key}}
                    @title={{key}}
                    as |field|
                  >
                    <field.Control />
                  </object.Field>
                {{/let}}
              {{/each}}
            </form.Object>
          </Form>
        </template>
      );

      const input = document.querySelector("[data-name='params.region'] input");
      await focus(input);
      await typeIn(input, "u", { delay: 0 });

      assert.strictEqual(document.activeElement, input, "focus retained");
    });

    test("retains focus when @type depends on yielded data on top-level field", async function (assert) {
      await render(
        <template>
          <Form @data={{hash provider="aws_bedrock" region=""}} as |form data|>
            <form.Field
              @type={{fieldType data.provider}}
              @name="region"
              @title="region"
              as |field|
            >
              <field.Control />
            </form.Field>
          </Form>
        </template>
      );

      const input = document.querySelector("[data-name='region'] input");
      await focus(input);
      await typeIn(input, "u", { delay: 0 });

      assert.strictEqual(document.activeElement, input, "focus retained");
    });
  }
);
