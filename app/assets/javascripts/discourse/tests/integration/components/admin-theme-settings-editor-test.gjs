import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ThemeSettingsEditor from "admin/components/theme-settings-editor";

module(
  "Integration | Component | admin-theme-settings-editor",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders passed json model object into string in the ace editor", async function (assert) {
      const model = {
        model: {
          settings: [
            { setting: "setting1", value: "value1" },
            { setting: "setting2", value: "value2" },
          ],
        },
      };

      await render(<template>
        <ThemeSettingsEditor @model={{model}} />
      </template>);

      assert.dom(".ace_line").hasText("[");
    });

    test("input is valid json", async function (assert) {
      const model = [];

      await render(<template>
        <ThemeSettingsEditor @model={{model}} />
      </template>);

      await fillIn(".ace textarea", "foo");
      await click("button#save");

      assert.dom(".validation-error").hasText(/Syntax Error/);
    });

    test("'setting' key is present for each setting", async function (assert) {
      const model = [];

      await render(<template>
        <ThemeSettingsEditor @model={{model}} />
      </template>);

      await fillIn(".ace textarea", `[{ "value": "value1" }]`);
      await click("button#save");

      assert.dom(".validation-error").hasText(/Syntax Error/);
    });

    test("'value' key is present for each setting", async function (assert) {
      const model = [];

      await render(<template>
        <ThemeSettingsEditor @model={{model}} />
      </template>);

      await fillIn(".ace textarea", `[{ "setting": "setting1" }]`);
      await click("button#save");

      assert.dom(".validation-error").hasText(/Syntax Error/);
    });

    test("only 'setting' and 'value' keys are present, no others", async function (assert) {
      const model = [];

      await render(<template>
        <ThemeSettingsEditor @model={{model}} />
      </template>);

      await fillIn(".ace textarea", `[{ "other_key": "other-key-1" }]`);
      await click("button#save");

      assert.dom(".validation-error").hasText(/Syntax Error/);
    });

    test("no settings are deleted", async function (assert) {
      const model = {
        model: {
          settings: [{ setting: "foo", value: "foo" }],
        },
      };

      await render(<template>
        <ThemeSettingsEditor @model={{model}} />
      </template>);

      document
        .querySelector(".ace")
        .aceEditor.session.doc.setValue(
          JSON.stringify([{ setting: "bar", value: "bar" }])
        );
      await click("button#save");

      assert
        .dom(".validation-error")
        .hasText(
          "foo: These settings were deleted. Please restore them and try again."
        );
    });

    test("no settings are added", async function (assert) {
      const model = {
        model: {
          settings: [{ setting: "bar", value: "bar" }],
        },
      };

      await render(<template>
        <ThemeSettingsEditor @model={{model}} />
      </template>);

      document.querySelector(".ace").aceEditor.session.doc.setValue(
        JSON.stringify([
          { setting: "foo", value: "foo" },
          { setting: "bar", value: "bar" },
        ])
      );
      await click("button#save");

      assert
        .dom(".validation-error")
        .hasText(
          "foo: These settings were added. Please remove them and try again."
        );
    });
  }
);
