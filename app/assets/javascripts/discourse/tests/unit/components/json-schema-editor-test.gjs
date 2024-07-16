import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import JsonSchemaEditor from "discourse/components/modal/json-schema-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const TEST_SCHEMA = {
  type: "array",
  uniqueItems: true,
  items: {
    type: "object",
    properties: { color: { type: "string" }, icon: { type: "string" } },
    additionalProperties: false,
  },
};

module("Unit | Component | <JsonSchemaEditor />", function (hooks) {
  setupRenderingTest(hooks);

  test("modal functions correctly", async function (assert) {
    let result;
    const model = {
      value: "[]",
      settingName: "My setting name",
      jsonSchema: TEST_SCHEMA,
      updateValue: (val) => (result = val),
    };

    const closeModal = () => {};

    await render(<template>
      <JsonSchemaEditor
        @inline={{true}}
        @model={{model}}
        @closeModal={{closeModal}}
      />
    </template>);

    await click(".json-editor-btn-add");
    await fillIn("[name='root[0][color]']", "red");
    await click(".d-modal__footer .btn-primary");

    assert.deepEqual(JSON.parse(result), [{ color: "red", icon: "" }]);
  });
});
