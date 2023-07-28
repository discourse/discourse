import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";

/*
example valid content for ace editor:
[
	{
		"setting": "whitelisted_fruits",
		"value": "uudu"
	},
	{
		"setting": "favorite_fruit",
		"value": "orange"
	},
	{
		"setting": "year",
		"value": 1992
	},
	{
		"setting": "banner_links",
		"value": "[{\"icon\":\"info-circle\",\"text\":\"about this site\",\"url\":\"/faq\"}, {\"icon\":\"users\",\"text\":\"meet our staff\",\"url\":\"/about\"}, {\"icon\":\"star\",\"text\":\"your preferences\",\"url\":\"/my/preferences\"}]"
	}
]
 */

function glimmerComponent(owner, componentName, args = {}) {
  const { class: componentClass } = owner.factoryFor(
    `component:${componentName}`
  );
  let componentManager = owner.lookup("component-manager:glimmer");
  let component = componentManager.createComponent(componentClass, {
    named: args,
  });
  return component;
}

module(
  "Integration | Component | admin-theme-settings-editor",
  function (hooks) {
    setupRenderingTest(hooks);

    let model;

    test("renders passed json model object into string in the ace editor", async function (assert) {
      await render(hbs`<ThemeSettingsEditor @model={{hash
        model=(hash
         settings=(array
          (hash
            setting='setting1'
            value='value1')
          (hash
            setting='setting2'
            value='value2')
          )
        )
    }} />`);
      const lines = document.querySelectorAll(".ace_line");
      const indexOf = lines[0].innerHTML.indexOf("[");
      assert.ok(indexOf >= 0);
    });

    test("input is valid json", async function (assert) {
      const component = glimmerComponent(this.owner, "theme-settings-editor", {
        model: [],
      });
      component.editedContent = "foo";
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("'setting' key is present for each setting", async function (assert) {
      const component = glimmerComponent(this.owner, "theme-settings-editor", {
        model: [],
      });

      component.editedContent = JSON.stringify([{ value: "value1" }]);
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("'value' key is present for each setting", async function (assert) {
      const component = glimmerComponent(this.owner, "theme-settings-editor", {
        model: [],
      });

      component.editedContent = JSON.stringify([{ setting: "setting1" }]);
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("only 'setting' and 'value' keys are present, no others", async function (assert) {
      const component = glimmerComponent(this.owner, "theme-settings-editor", {
        model: [],
      });

      component.editedContent = JSON.stringify([{ otherkey: "otherkey1" }]);
      component.save();
      assert.strictEqual(component.errors[0].setting, "Syntax Error");
    });

    test("no settings are deleted", async function (assert) {
      model = {
        model: {
          settings: [
            { setting: "foo", value: "foo" },
            { setting: "bar", value: "bar" },
          ],
        },
      };
      const component = glimmerComponent(this.owner, "theme-settings-editor", {
        model,
      });

      component.editedContent = JSON.stringify([
        { setting: "bar", value: "bar" },
      ]);
      component.save();

      assert.strictEqual(component.errors[0].setting, "foo");
    });

    test("no settings are added", async function (assert) {
      model = {
        model: {
          settings: [{ setting: "bar", value: "bar" }],
        },
      };

      const component = glimmerComponent(this.owner, "theme-settings-editor", {
        model,
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
