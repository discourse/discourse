import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import schemaAndData from "discourse/tests/fixtures/theme-setting-schema-data";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";
import AdminSchemaThemeSettingEditor from "admin/components/schema-theme-setting/editor";

class TreeFromDOM {
  constructor() {
    this.refresh();
  }

  refresh() {
    this.nodes = [...queryAll(".tree .item-container")].map((container) => {
      const li = container.querySelector(".parent.node");
      const active = li.classList.contains("active");
      const children = [...container.querySelectorAll(".node.child")].map(
        (child) => {
          return {
            text: child.textContent.trim(),
            element: child,
          };
        }
      );

      return {
        text: li.textContent.trim(),
        active,
        children,
        element: li,
      };
    });
  }
}

class InputFieldsFromDOM {
  constructor() {
    this.refresh();
  }

  refresh() {
    this.fields = {};
    this.count = 0;
    [...queryAll(".schema-field")].forEach((field) => {
      this.count += 1;
      this.fields[field.dataset.name] = {
        labelElement: field.querySelector("label"),
        inputElement: field.querySelector(".input").children[0],
        selector: `.schema-field[data-name="${field.dataset.name}"]`,
      };
    });
  }
}

module(
  "Integration | Admin | Component | schema-theme-setting/editor",
  function (hooks) {
    setupRenderingTest(hooks);

    test("activates the first node by default", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.strictEqual(tree.nodes.length, 2);
      assert.true(tree.nodes[0].active, "the first node is active");
      assert.false(tree.nodes[1].active, "other nodes are not active");
    });

    test("renders the 2nd level of nested items for the active item only", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.true(tree.nodes[0].active);
      assert.strictEqual(
        tree.nodes[0].children.length,
        2,
        "the children of the active node are shown"
      );

      assert.false(tree.nodes[1].active);
      assert.strictEqual(
        tree.nodes[1].children.length,
        0,
        "thie children of an active node aren't shown"
      );

      await click(tree.nodes[1].element);

      tree.refresh();

      assert.false(tree.nodes[0].active);
      assert.strictEqual(
        tree.nodes[0].children.length,
        0,
        "thie children of an active node aren't shown"
      );

      assert.true(tree.nodes[1].active);
      assert.strictEqual(
        tree.nodes[1].children.length,
        3,
        "the children of the active node are shown"
      );
    });

    test("allows navigating through multiple levels of nesting", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.strictEqual(tree.nodes.length, 2);
      assert.strictEqual(tree.nodes[0].text, "item 1");
      assert.strictEqual(tree.nodes[0].children.length, 2);
      assert.strictEqual(tree.nodes[0].children[0].text, "child 1-1");
      assert.strictEqual(tree.nodes[0].children[1].text, "child 1-2");

      assert.strictEqual(tree.nodes[1].text, "item 2");
      assert.strictEqual(tree.nodes[1].children.length, 0);

      await click(tree.nodes[1].element);

      tree.refresh();

      assert.strictEqual(tree.nodes.length, 2);
      assert.strictEqual(tree.nodes[0].text, "item 1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.strictEqual(tree.nodes[1].text, "item 2");
      assert.true(tree.nodes[1].active);
      assert.strictEqual(tree.nodes[1].children.length, 3);
      assert.strictEqual(tree.nodes[1].children[0].text, "child 2-1");
      assert.strictEqual(tree.nodes[1].children[1].text, "child 2-2");
      assert.strictEqual(tree.nodes[1].children[2].text, "child 2-3");

      await click(tree.nodes[1].children[1].element);

      tree.refresh();
      assert.strictEqual(tree.nodes.length, 3);

      assert.strictEqual(tree.nodes[0].text, "child 2-1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.strictEqual(tree.nodes[1].text, "child 2-2");
      assert.true(tree.nodes[1].active);
      assert.strictEqual(tree.nodes[1].children.length, 4);
      assert.strictEqual(tree.nodes[1].children[0].text, "grandchild 2-2-1");
      assert.strictEqual(tree.nodes[1].children[1].text, "grandchild 2-2-2");
      assert.strictEqual(tree.nodes[1].children[2].text, "grandchild 2-2-3");
      assert.strictEqual(tree.nodes[1].children[3].text, "grandchild 2-2-4");

      assert.strictEqual(tree.nodes[2].text, "child 2-3");
      assert.false(tree.nodes[2].active);
      assert.strictEqual(tree.nodes[2].children.length, 0);

      await click(tree.nodes[1].children[1].element);

      tree.refresh();

      assert.strictEqual(tree.nodes.length, 4);

      assert.strictEqual(tree.nodes[0].text, "grandchild 2-2-1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.strictEqual(tree.nodes[1].text, "grandchild 2-2-2");
      assert.true(tree.nodes[1].active);
      assert.strictEqual(tree.nodes[1].children.length, 0);

      assert.strictEqual(tree.nodes[2].text, "grandchild 2-2-3");
      assert.false(tree.nodes[2].active);
      assert.strictEqual(tree.nodes[2].children.length, 0);

      assert.strictEqual(tree.nodes[3].text, "grandchild 2-2-4");
      assert.false(tree.nodes[3].active);
      assert.strictEqual(tree.nodes[3].children.length, 0);
    });

    test("the back button is only shown when the navigation is at least one level deep", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      assert.dom(".back-button").doesNotExist();

      const tree = new TreeFromDOM();
      await click(tree.nodes[0].children[0].element);

      assert.dom(".back-button").exists();
      tree.refresh();
      assert.strictEqual(tree.nodes[0].text, "child 1-1");

      await click(tree.nodes[0].children[0].element);

      tree.refresh();
      assert.strictEqual(tree.nodes[0].text, "grandchild 1-1-1");
      assert.dom(".back-button").exists();

      await click(".back-button");

      tree.refresh();
      assert.strictEqual(tree.nodes[0].text, "child 1-1");
      assert.dom(".back-button").exists();

      await click(".back-button");

      tree.refresh();
      assert.strictEqual(tree.nodes[0].text, "item 1");
      assert.dom(".back-button").doesNotExist();
    });

    test("the back button navigates to the index of the active element at the previous level", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);

      tree.refresh();
      await click(tree.nodes[1].children[1].element);

      await click(".back-button");
      tree.refresh();

      assert.strictEqual(tree.nodes.length, 2);

      assert.strictEqual(tree.nodes[0].text, "item 1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.strictEqual(tree.nodes[1].text, "item 2");
      assert.true(tree.nodes[1].active);
      assert.strictEqual(tree.nodes[1].children.length, 3);
    });

    test("the back button label includes the name of the item at the previous level", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);

      tree.refresh();
      await click(tree.nodes[1].children[1].element);

      assert.dom(".back-button").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "item 2",
        })
      );

      tree.refresh();
      await click(tree.nodes[1].children[0].element);

      assert.dom(".back-button").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "child 2-2",
        })
      );

      await click(".back-button");

      assert.dom(".back-button").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "item 2",
        })
      );
    });

    test("input fields for items at different levels", async function (assert) {
      const setting = schemaAndData(2);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.name.labelElement).hasText("name");
      assert.dom(inputFields.fields.icon.labelElement).hasText("icon");

      assert.dom(inputFields.fields.name.inputElement).hasValue("nice section");
      assert.dom(inputFields.fields.icon.inputElement).hasValue("arrow");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);

      inputFields.refresh();
      tree.refresh();

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.name.labelElement).hasText("name");
      assert.dom(inputFields.fields.icon.labelElement).hasText("icon");

      assert.dom(inputFields.fields.name.inputElement).hasValue("cool section");
      assert.dom(inputFields.fields.icon.inputElement).hasValue("bell");

      await click(tree.nodes[1].children[0].element);

      tree.refresh();
      inputFields.refresh();

      assert.strictEqual(inputFields.count, 3);
      assert.dom(inputFields.fields.text.labelElement).hasText("text");
      assert.dom(inputFields.fields.url.labelElement).hasText("url");
      assert.dom(inputFields.fields.icon.labelElement).hasText("icon");

      assert.dom(inputFields.fields.text.inputElement).hasValue("About");
      assert
        .dom(inputFields.fields.url.inputElement)
        .hasValue("https://example.com/about");
      assert.dom(inputFields.fields.icon.inputElement).hasValue("asterisk");
    });

    test("input fields of type integer", async function (assert) {
      const setting = schemaAndData(3);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      assert
        .dom(inputFields.fields.integer_field.labelElement)
        .hasText("integer_field");
      assert.dom(inputFields.fields.integer_field.inputElement).hasValue("92");
      assert
        .dom(inputFields.fields.integer_field.inputElement)
        .hasAttribute("type", "number");
      await fillIn(inputFields.fields.integer_field.inputElement, "922229");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);

      inputFields.refresh();

      assert.dom(inputFields.fields.integer_field.inputElement).hasValue("820");

      tree.refresh();
      await click(tree.nodes[0].element);
      inputFields.refresh();

      assert
        .dom(inputFields.fields.integer_field.inputElement)
        .hasValue("922229");
    });

    test("input fields of type boolean", async function (assert) {
      const setting = schemaAndData(3);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      assert
        .dom(inputFields.fields.boolean_field.labelElement)
        .hasText("boolean_field");
      assert.dom(inputFields.fields.boolean_field.inputElement).isChecked();
      await click(inputFields.fields.boolean_field.inputElement);

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);

      inputFields.refresh();
      assert
        .dom(inputFields.fields.boolean_field.labelElement)
        .hasText("boolean_field");
      assert.dom(inputFields.fields.boolean_field.inputElement).isNotChecked();

      tree.refresh();
      await click(tree.nodes[0].element);
      inputFields.refresh();

      assert.dom(inputFields.fields.boolean_field.inputElement).isNotChecked();
    });

    test("input fields of type enum", async function (assert) {
      const setting = schemaAndData(3);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      const enumSelector = selectKit(
        `${inputFields.fields.enum_field.selector} .select-kit`
      );
      assert.strictEqual(enumSelector.header().value(), "awesome");

      await enumSelector.expand();
      await enumSelector.selectRowByValue("nice");
      assert.strictEqual(enumSelector.header().value(), "nice");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);
      assert.strictEqual(enumSelector.header().value(), "cool");

      tree.refresh();

      await click(tree.nodes[0].element);
      assert.strictEqual(enumSelector.header().value(), "nice");
    });

    test("identifier field instantly updates in the navigation tree when the input field is changed", async function (assert) {
      const setting = schemaAndData(2);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      const tree = new TreeFromDOM();

      await fillIn(
        inputFields.fields.name.inputElement,
        "nice section is really nice"
      );

      assert.dom(tree.nodes[0].element).hasText("nice section is really nice");

      await click(tree.nodes[0].children[0].element);

      inputFields.refresh();
      tree.refresh();

      await fillIn(
        inputFields.fields.text.inputElement,
        "Security instead of Privacy"
      );

      assert.dom(tree.nodes[0].element).hasText("Security instead of Privacy");
    });

    test("edits are remembered when navigating between levels", async function (assert) {
      const setting = schemaAndData(2);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      const tree = new TreeFromDOM();

      await fillIn(
        inputFields.fields.name.inputElement,
        "changed section name"
      );

      await click(tree.nodes[1].element);

      tree.refresh();
      inputFields.refresh();

      await fillIn(
        inputFields.fields.name.inputElement,
        "cool section is no longer cool"
      );

      await click(tree.nodes[1].children[1].element);

      tree.refresh();
      inputFields.refresh();

      assert.dom(".back-button").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "cool section is no longer cool",
        })
      );

      await fillIn(inputFields.fields.text.inputElement, "Talk to us");

      await click(".back-button");

      tree.refresh();
      inputFields.refresh();

      assert.dom(tree.nodes[0].element).hasText("changed section name");
      assert
        .dom(tree.nodes[1].element)
        .hasText("cool section is no longer cool");

      assert.dom(tree.nodes[1].children[0].element).hasText("About");
      assert.dom(tree.nodes[1].children[1].element).hasText("Talk to us");

      assert
        .dom(inputFields.fields.name.inputElement)
        .hasValue("cool section is no longer cool");

      await click(tree.nodes[1].children[1].element);

      tree.refresh();
      inputFields.refresh();

      assert.dom(inputFields.fields.text.inputElement).hasValue("Talk to us");
    });
  }
);
