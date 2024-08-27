import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ThemeSettingsEditor from "admin/components/theme-settings-editor";

function glimmerComponent(owner, componentClass, args = {}) {
  const componentManager = owner.lookup("component-manager:glimmer");
  return componentManager.createComponent(componentClass, {
    named: args,
  });
}

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
      const component = glimmerComponent(this.owner, ThemeSettingsEditor, {
        model: [],
      });

      component.editedContent = "foo";
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("'setting' key is present for each setting", async function (assert) {
      const component = glimmerComponent(this.owner, ThemeSettingsEditor, {
        model: [],
      });

      component.editedContent = JSON.stringify([{ value: "value1" }]);
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("'value' key is present for each setting", async function (assert) {
      const component = glimmerComponent(this.owner, ThemeSettingsEditor, {
        model: [],
      });

      component.editedContent = JSON.stringify([{ setting: "setting1" }]);
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("only 'setting' and 'value' keys are present, no others", async function (assert) {
      const component = glimmerComponent(this.owner, ThemeSettingsEditor, {
        model: [],
      });

      component.editedContent = JSON.stringify([{ other_key: "other-key-1" }]);
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("no settings are deleted", async function (assert) {
      const component = glimmerComponent(this.owner, ThemeSettingsEditor, {
        model: {
          model: {
            settings: [
              { setting: "foo", value: "foo" },
              { setting: "bar", value: "bar" },
            ],
          },
        },
      });

      component.editedContent = JSON.stringify([
        { setting: "bar", value: "bar" },
      ]);
      component.save();

      assert.strictEqual(component.errors[0].setting, "foo");
    });

    test("no settings are added", async function (assert) {
      const component = glimmerComponent(this.owner, ThemeSettingsEditor, {
        model: {
          model: {
            settings: [{ setting: "bar", value: "bar" }],
          },
        },
      });

      component.editedContent = JSON.stringify([
        { setting: "foo", value: "foo" },
        { setting: "bar", value: "bar" },
      ]);
      component.save();

      assert.strictEqual(component.errors[0].setting, "foo");
    });
  }
);
