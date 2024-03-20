import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import schemaAndData from "discourse/tests/fixtures/theme-setting-schema-data";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";
import AdminSchemaThemeSettingEditor from "admin/components/schema-theme-setting/editor";
import ThemeSettings from "admin/models/theme-settings";

class TreeFromDOM {
  constructor() {
    this.refresh();
  }

  refresh() {
    this.nodes = [
      ...queryAll(
        ".schema-theme-setting-editor__tree .schema-theme-setting-editor__tree-node.--parent"
      ),
    ].map((container, index) => {
      const li = container;
      const active = li.classList.contains("--active");

      const children = [
        ...queryAll(
          `.schema-theme-setting-editor__tree-node.--child[data-test-parent-index="${index}"]:not(.--heading)`
        ),
      ].map((child) => {
        return {
          element: child,
          textElement: child.querySelector(
            ".schema-theme-setting-editor__tree-node-text"
          ),
        };
      });

      const addButtons = [
        ...queryAll(
          `.schema-theme-setting-editor__tree-add-button.--child[data-test-parent-index="${index}"]`
        ),
      ];

      return {
        active,
        children,
        addButtons,
        element: li,
        textElement: li.querySelector(
          ".schema-theme-setting-editor__tree-node-text"
        ),
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
        labelElement: field.querySelector(".schema-field__label"),
        inputElement: field.querySelector(".schema-field__input").children[0],
        selector: `.schema-field[data-name="${field.dataset.name}"]`,
      };
    });
  }
}

const TOP_LEVEL_ADD_BTN =
  ".schema-theme-setting-editor__tree-add-button.--root";
const REMOVE_ITEM_BTN = ".schema-theme-setting-editor__remove-btn";

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

      assert.strictEqual(tree.nodes.length, 3);
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

      assert.strictEqual(tree.nodes.length, 3);
      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.strictEqual(tree.nodes[0].children.length, 2);
      assert.dom(tree.nodes[0].children[0].textElement).hasText("child 1-1");
      assert.dom(tree.nodes[0].children[1].textElement).hasText("child 1-2");

      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.strictEqual(tree.nodes[1].children.length, 0);

      await click(tree.nodes[1].element);

      tree.refresh();

      assert.strictEqual(tree.nodes.length, 3);
      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.true(tree.nodes[1].active);
      assert.strictEqual(tree.nodes[1].children.length, 3);
      assert.dom(tree.nodes[1].children[0].textElement).hasText("child 2-1");
      assert.dom(tree.nodes[1].children[1].textElement).hasText("child 2-2");
      assert.dom(tree.nodes[1].children[2].textElement).hasText("child 2-3");

      await click(tree.nodes[1].children[1].element);

      tree.refresh();
      assert.strictEqual(tree.nodes.length, 4);

      assert.dom(tree.nodes[0].textElement).hasText("child 2-1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.dom(tree.nodes[1].textElement).hasText("child 2-2");
      assert.true(tree.nodes[1].active);
      assert.strictEqual(tree.nodes[1].children.length, 4);

      assert
        .dom(tree.nodes[1].children[0].textElement)
        .hasText("grandchild 2-2-1");

      assert
        .dom(tree.nodes[1].children[1].textElement)
        .hasText("grandchild 2-2-2");

      assert
        .dom(tree.nodes[1].children[2].textElement)
        .hasText("grandchild 2-2-3");

      assert
        .dom(tree.nodes[1].children[3].textElement)
        .hasText("grandchild 2-2-4");

      assert.dom(tree.nodes[2].textElement).hasText("child 2-3");
      assert.false(tree.nodes[2].active);
      assert.strictEqual(tree.nodes[2].children.length, 0);

      await click(tree.nodes[1].children[1].element);

      tree.refresh();

      assert.strictEqual(tree.nodes.length, 5);

      assert.dom(tree.nodes[0].textElement).hasText("grandchild 2-2-1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.dom(tree.nodes[1].textElement).hasText("grandchild 2-2-2");
      assert.true(tree.nodes[1].active);
      assert.strictEqual(tree.nodes[1].children.length, 0);

      assert.dom(tree.nodes[2].textElement).hasText("grandchild 2-2-3");
      assert.false(tree.nodes[2].active);
      assert.strictEqual(tree.nodes[2].children.length, 0);

      assert.dom(tree.nodes[3].textElement).hasText("grandchild 2-2-4");
      assert.false(tree.nodes[3].active);
      assert.strictEqual(tree.nodes[3].children.length, 0);
    });

    test("the back button is only shown when the navigation is at least one level deep", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      assert.dom(".--back-btn").doesNotExist();

      const tree = new TreeFromDOM();
      await click(tree.nodes[0].children[0].element);

      assert.dom(".--back-btn").exists();
      tree.refresh();
      assert.dom(tree.nodes[0].textElement).hasText("child 1-1");

      await click(tree.nodes[0].children[0].element);

      tree.refresh();
      assert.dom(tree.nodes[0].textElement).hasText("grandchild 1-1-1");
      assert.dom(".--back-btn").exists();

      await click(".--back-btn");

      tree.refresh();
      assert.dom(tree.nodes[0].textElement).hasText("child 1-1");
      assert.dom(".--back-btn").exists();

      await click(".--back-btn");

      tree.refresh();
      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.dom(".--back-btn").doesNotExist();
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

      await click(".--back-btn");
      tree.refresh();

      assert.strictEqual(tree.nodes.length, 3);

      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.false(tree.nodes[0].active);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.dom(tree.nodes[1].textElement).hasText("item 2");
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

      assert.dom(".--back-btn").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "item 2",
        })
      );

      tree.refresh();
      await click(tree.nodes[1].children[0].element);

      assert.dom(".--back-btn").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "child 2-2",
        })
      );

      await click(".--back-btn");

      assert.dom(".--back-btn").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "item 2",
        })
      );
    });

    test("input fields are rendered even if they're not present in the data", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          identifier: "id",
          properties: {
            id: {
              type: "string",
            },
            name: {
              type: "string",
            },
          },
        },
        value: [
          {
            id: "bu1",
            name: "Big U",
          },
          {
            id: "fi2",
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.id.inputElement).hasValue("bu1");
      assert.dom(inputFields.fields.name.inputElement).hasValue("Big U");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);
      inputFields.refresh();

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.id.inputElement).hasValue("fi2");
      assert.dom(inputFields.fields.name.inputElement).hasNoValue();
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
      assert.dom(inputFields.fields.text.inputElement).hasValue("Contact");

      assert
        .dom(inputFields.fields.url.inputElement)
        .hasValue("https://example.com/contact");

      assert.dom(inputFields.fields.icon.inputElement).hasValue("phone");
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

    test("input fields of type float", async function (assert) {
      const setting = schemaAndData(3);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      assert
        .dom(inputFields.fields.float_field.labelElement)
        .hasText("float_field");
      assert.dom(inputFields.fields.float_field.inputElement).hasValue("");

      await fillIn(inputFields.fields.float_field.inputElement, "6934.24");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);

      inputFields.refresh();

      assert.dom(inputFields.fields.float_field.inputElement).hasValue("");

      tree.refresh();
      await click(tree.nodes[0].element);
      inputFields.refresh();

      assert
        .dom(inputFields.fields.float_field.inputElement)
        .hasValue("6934.24");
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

    test("input fields of type category", async function (assert) {
      const setting = schemaAndData(3);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      const categorySelector = selectKit(
        `${inputFields.fields.category_field.selector} .select-kit`
      );

      assert.strictEqual(categorySelector.header().value(), null);

      await categorySelector.expand();
      await categorySelector.selectRowByIndex(1);

      const selectedCategoryId = categorySelector.header().value();
      assert.ok(selectedCategoryId);

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);
      assert.strictEqual(categorySelector.header().value(), null);

      tree.refresh();

      await click(tree.nodes[0].element);
      assert.strictEqual(categorySelector.header().value(), selectedCategoryId);
    });

    test("input fields of type tag", async function (assert) {
      const setting = schemaAndData(3);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      const tagSelector = selectKit(
        `${inputFields.fields.tag_field.selector} .select-kit`
      );

      assert.strictEqual(tagSelector.header().value(), null);

      await tagSelector.expand();
      await tagSelector.selectRowByIndex(1);
      await tagSelector.selectRowByIndex(3);

      assert.strictEqual(tagSelector.header().value(), "gazelle,cat");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);
      assert.strictEqual(tagSelector.header().value(), null);

      tree.refresh();

      await click(tree.nodes[0].element);
      assert.strictEqual(tagSelector.header().value(), "gazelle,cat");
    });

    test("input fields of type group", async function (assert) {
      pretender.get("/groups/search.json", () => {
        return response(200, [
          { id: 23, name: "testers" },
          { id: 74, name: "devs" },
          { id: 89, name: "customers" },
        ]);
      });

      const setting = schemaAndData(3);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();
      const groupSelector = selectKit(
        `${inputFields.fields.group_field.selector} .select-kit`
      );

      assert.strictEqual(groupSelector.header().value(), null);

      await groupSelector.expand();
      await groupSelector.selectRowByValue(74);
      assert.strictEqual(groupSelector.header().value(), "74");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);

      assert.strictEqual(groupSelector.header().value(), null);
      await groupSelector.expand();
      await groupSelector.selectRowByValue(23);
      assert.strictEqual(groupSelector.header().value(), "23");

      tree.refresh();

      await click(tree.nodes[0].element);
      assert.strictEqual(groupSelector.header().value(), "74");
    });

    test("generic identifier is used when identifier is not specified in the schema", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "section",
          properties: {
            name: {
              type: "string",
            },
            links: {
              type: "objects",
              schema: {
                name: "link",
                properties: {
                  title: {
                    type: "string",
                  },
                },
              },
            },
          },
        },
        value: [
          {
            name: "some section",
            links: [
              {
                title: "some title",
              },
              {
                title: "some other title",
              },
            ],
          },
          {
            name: "some section 2",
            links: [
              {
                title: "some title 3",
              },
            ],
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.dom(tree.nodes[0].textElement).hasText("section 1");
      assert.dom(tree.nodes[0].children[0].textElement).hasText("link 1");
      assert.dom(tree.nodes[0].children[1].textElement).hasText("link 2");
      assert.dom(tree.nodes[1].textElement).hasText("section 2");

      await click(tree.nodes[1].element);

      tree.refresh();

      assert.dom(tree.nodes[1].children[0].textElement).hasText("link 1");
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

      assert
        .dom(tree.nodes[0].textElement)
        .hasText("nice section is really nice");

      await click(tree.nodes[0].children[0].element);

      inputFields.refresh();
      tree.refresh();

      await fillIn(
        inputFields.fields.text.inputElement,
        "Security instead of Privacy"
      );

      assert
        .dom(tree.nodes[0].textElement)
        .hasText("Security instead of Privacy");
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

      assert.dom(".--back-btn").hasText(
        I18n.t("admin.customize.theme.schema.back_button", {
          name: "cool section is no longer cool",
        })
      );

      await fillIn(inputFields.fields.text.inputElement, "Talk to us");
      await click(".--back-btn");

      tree.refresh();
      inputFields.refresh();

      assert.dom(tree.nodes[0].textElement).hasText("changed section name");

      assert
        .dom(tree.nodes[1].textElement)
        .hasText("cool section is no longer cool");

      assert.dom(tree.nodes[1].children[0].textElement).hasText("About");
      assert.dom(tree.nodes[1].children[1].textElement).hasText("Talk to us");

      assert
        .dom(inputFields.fields.name.inputElement)
        .hasValue("cool section is no longer cool");

      await click(tree.nodes[1].children[1].element);

      tree.refresh();
      inputFields.refresh();

      assert.dom(inputFields.fields.text.inputElement).hasValue("Talk to us");
    });

    test("adding an object to the root list of objects", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      assert.dom(TOP_LEVEL_ADD_BTN).hasText("level1");

      const tree = new TreeFromDOM();

      assert.strictEqual(tree.nodes.length, 3);

      await click(TOP_LEVEL_ADD_BTN);
      await click(TOP_LEVEL_ADD_BTN);
      tree.refresh();

      assert.strictEqual(tree.nodes.length, 5);
      assert.dom(tree.nodes[2].textElement).hasText("level1 3");
      assert.dom(tree.nodes[3].textElement).hasText("level1 4");
    });

    test("adding an object to a child list of objects", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.dom(tree.nodes[0].addButtons[0]).hasText("level2");
      assert.strictEqual(tree.nodes[0].children.length, 2);

      await click(tree.nodes[0].addButtons[0]);
      tree.refresh();

      await click(tree.nodes[0].addButtons[0]);
      tree.refresh();

      assert.strictEqual(tree.nodes[0].children.length, 4);
      assert.dom(tree.nodes[0].children[2].textElement).hasText("level2 3");
      assert.dom(tree.nodes[0].children[3].textElement).hasText("level2 4");
    });

    test("navigating 1 level deep and adding an object to the child list of objects that's displayed as the root list", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      await click(tree.nodes[0].children[0].element);
      tree.refresh();

      assert.dom(TOP_LEVEL_ADD_BTN).hasText("level2");
      assert.strictEqual(tree.nodes.length, 3);

      await click(TOP_LEVEL_ADD_BTN);
      await click(TOP_LEVEL_ADD_BTN);

      tree.refresh();
      assert.strictEqual(tree.nodes.length, 5);
      assert.dom(tree.nodes[2].textElement).hasText("level2 3");
      assert.dom(tree.nodes[3].textElement).hasText("level2 4");
    });

    test("navigating 1 level deep and adding an object to a grandchild list of objects", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      await click(tree.nodes[0].children[0].element);
      tree.refresh();

      assert.dom(tree.nodes[0].addButtons[0]).hasText("level3");
      assert.strictEqual(tree.nodes[0].children.length, 2);

      await click(tree.nodes[0].addButtons[0]);
      tree.refresh();

      await click(tree.nodes[0].addButtons[0]);
      tree.refresh();

      assert.strictEqual(tree.nodes[0].children.length, 4);
      assert.dom(tree.nodes[0].children[2].textElement).hasText("level3 3");
      assert.dom(tree.nodes[0].children[3].textElement).hasText("level3 4");
    });

    test("removing an object from the root list of objects", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();
      const inputFields = new InputFieldsFromDOM();

      assert.strictEqual(tree.nodes.length, 3);
      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("item 1");

      await click(REMOVE_ITEM_BTN);

      tree.refresh();
      inputFields.refresh();

      assert.strictEqual(tree.nodes.length, 2);
      assert.dom(tree.nodes[0].textElement).hasText("item 2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("item 2");

      await click(REMOVE_ITEM_BTN);

      tree.refresh();
      inputFields.refresh();

      assert.strictEqual(tree.nodes.length, 1);
      assert.strictEqual(inputFields.count, 0);
      assert.dom(REMOVE_ITEM_BTN).doesNotExist();
      assert.dom(TOP_LEVEL_ADD_BTN).hasText("level1");
    });

    test("navigating 1 level deep and removing an object from the child list of objects", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      await click(tree.nodes[0].children[1].element);
      tree.refresh();

      const inputFields = new InputFieldsFromDOM();

      assert.strictEqual(tree.nodes.length, 3);
      assert.dom(tree.nodes[0].textElement).hasText("child 1-1");
      assert.dom(tree.nodes[1].textElement).hasText("child 1-2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("child 1-1");

      await click(REMOVE_ITEM_BTN);

      tree.refresh();
      inputFields.refresh();

      assert.strictEqual(tree.nodes.length, 2);
      assert.dom(tree.nodes[0].textElement).hasText("child 1-2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("child 1-2");

      // removing the last object navigates back to the previous level
      await click(REMOVE_ITEM_BTN);

      tree.refresh();
      inputFields.refresh();

      assert.strictEqual(tree.nodes.length, 3);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("item 1");
      assert.dom(".--back-btn").doesNotExist();
    });
  }
);
