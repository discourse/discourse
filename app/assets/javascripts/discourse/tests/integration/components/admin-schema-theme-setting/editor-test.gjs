import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import schemaAndData from "discourse/tests/fixtures/theme-setting-schema-data";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
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
          `.schema-theme-setting-editor__tree-node.--child[data-test-parent-index="${index}"]`
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
        countElement: field.querySelector(".schema-field__input-count"),
        errorElement: field.querySelector(".schema-field__input-error"),
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
        i18n("admin.customize.theme.schema.back_button", {
          name: "item 2",
        })
      );

      tree.refresh();
      await click(tree.nodes[1].children[0].element);

      assert.dom(".--back-btn").hasText(
        i18n("admin.customize.theme.schema.back_button", {
          name: "child 2-2",
        })
      );

      await click(".--back-btn");

      assert.dom(".--back-btn").hasText(
        i18n("admin.customize.theme.schema.back_button", {
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

    test("input fields of type string", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          identifier: "id",
          properties: {
            id: {
              type: "string",
              required: true,
              validations: {
                max_length: 5,
                min_length: 2,
              },
            },
          },
        },
        value: [
          {
            id: "bu1",
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      assert.dom(inputFields.fields.id.labelElement).hasText("id*");
      assert.dom(inputFields.fields.id.countElement).hasText("3/5");

      await fillIn(inputFields.fields.id.inputElement, "1");

      assert.dom(inputFields.fields.id.countElement).hasText("1/5");

      inputFields.refresh();

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.string.too_short", {
          count: 2,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "");

      assert.dom(inputFields.fields.id.countElement).hasText("0/5");

      assert
        .dom(inputFields.fields.id.errorElement)
        .hasText(i18n("admin.customize.theme.schema.fields.required"));
    });

    test("input fields of type integer", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          identifier: "id",
          properties: {
            id: {
              type: "integer",
              required: true,
              validations: {
                max: 10,
                min: 5,
              },
            },
          },
        },
        value: [
          {
            id: 6,
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      assert.dom(inputFields.fields.id.labelElement).hasText("id*");
      assert.dom(inputFields.fields.id.inputElement).hasValue("6");

      assert
        .dom(inputFields.fields.id.inputElement)
        .hasAttribute("type", "number");

      await fillIn(inputFields.fields.id.inputElement, "922229");

      inputFields.refresh();

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.number.too_large", {
          count: 10,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "0");

      inputFields.refresh();

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.number.too_small", {
          count: 5,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "");

      inputFields.refresh();

      assert
        .dom(inputFields.fields.id.errorElement)
        .hasText(i18n("admin.customize.theme.schema.fields.required"));
    });

    test("input fields of type float", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          identifier: "id",
          properties: {
            id: {
              type: "float",
              required: true,
              validations: {
                max: 10.5,
                min: 5.5,
              },
            },
          },
        },
        value: [
          {
            id: 6.5,
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      assert.dom(inputFields.fields.id.labelElement).hasText("id*");
      assert.dom(inputFields.fields.id.inputElement).hasValue("6.5");

      assert
        .dom(inputFields.fields.id.inputElement)
        .hasAttribute("type", "number");

      await fillIn(inputFields.fields.id.inputElement, "100.0");

      inputFields.refresh();

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.number.too_large", {
          count: 10.5,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "0.2");

      inputFields.refresh();

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.number.too_small", {
          count: 5.5,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "");

      inputFields.refresh();

      assert
        .dom(inputFields.fields.id.errorElement)
        .hasText(i18n("admin.customize.theme.schema.fields.required"));
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
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          properties: {
            enum_field: {
              type: "enum",
              default: "awesome",
              choices: ["nice", "cool", "awesome"],
            },
            required_enum_field: {
              type: "enum",
              default: "awesome",
              required: true,
              choices: ["nice", "cool", "awesome"],
            },
          },
        },
        value: [
          {
            required_enum_field: "awesome",
          },
          {
            required_enum_field: "cool",
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      const enumSelector = selectKit(
        `${inputFields.fields.enum_field.selector} .select-kit`
      );

      assert.strictEqual(enumSelector.header().value(), null);

      const requiredEnumSelector = selectKit(
        `${inputFields.fields.required_enum_field.selector} .select-kit`
      );

      assert.strictEqual(requiredEnumSelector.header().value(), "awesome");

      await requiredEnumSelector.expand();
      await requiredEnumSelector.selectRowByValue("nice");

      assert.strictEqual(requiredEnumSelector.header().value(), "nice");

      const tree = new TreeFromDOM();
      await click(tree.nodes[1].element);
      assert.strictEqual(requiredEnumSelector.header().value(), "cool");

      tree.refresh();

      await click(tree.nodes[0].element);
      assert.strictEqual(requiredEnumSelector.header().value(), "nice");

      await click(TOP_LEVEL_ADD_BTN);

      assert.strictEqual(requiredEnumSelector.header().value(), "awesome");
    });

    test("input fields of type categories that is not required with min and max validations", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          properties: {
            not_required_category: {
              type: "categories",
              validations: {
                min: 2,
                max: 3,
              },
            },
          },
        },
        metadata: {
          categories: {
            6: {
              id: 6,
              name: "some category",
            },
          },
        },
        value: [{}],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      assert
        .dom(inputFields.fields.not_required_category.labelElement)
        .hasText("not_required_category");

      const categorySelector = selectKit(
        `${inputFields.fields.not_required_category.selector} .select-kit`
      );

      assert.strictEqual(categorySelector.header().value(), null);

      await categorySelector.expand();
      await categorySelector.selectRowByIndex(1);
      await categorySelector.collapse();

      inputFields.refresh();

      assert.dom(inputFields.fields.not_required_category.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.categories.at_least", {
          count: 2,
        })
      );

      await categorySelector.expand();
      await categorySelector.selectRowByIndex(2);
      await categorySelector.selectRowByIndex(3);
      await categorySelector.selectRowByIndex(4);

      assert
        .dom(categorySelector.error())
        .hasText("You can only select 3 items.");

      await categorySelector.deselectItemByIndex(0);
      await categorySelector.deselectItemByIndex(0);
      await categorySelector.deselectItemByIndex(0);
      await categorySelector.collapse();

      inputFields.refresh();

      assert
        .dom(inputFields.fields.not_required_category.errorElement)
        .doesNotExist();
    });

    test("input fields of type categories", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          identifier: "id",
          properties: {
            required_category: {
              type: "categories",
              required: true,
            },
          },
        },
        metadata: {
          categories: {
            6: {
              id: 6,
              name: "some category",
            },
          },
        },
        value: [
          {
            required_category: [6],
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      assert
        .dom(inputFields.fields.required_category.labelElement)
        .hasText("required_category*");

      let categorySelector = selectKit(
        `${inputFields.fields.required_category.selector} .select-kit`
      );

      assert.strictEqual(categorySelector.header().value(), "6");

      await categorySelector.expand();
      await categorySelector.deselectItemByValue("6");
      await categorySelector.collapse();

      inputFields.refresh();

      assert.dom(inputFields.fields.required_category.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.categories.at_least", {
          count: 1,
        })
      );
    });

    test("input field of type categories with schema's identifier set to categories field", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "category",
          identifier: "category",
          properties: {
            category: {
              type: "categories",
              required: true,
            },
          },
        },
        metadata: {
          categories: {
            6: {
              id: 6,
              name: "support",
            },
            7: {
              id: 7,
              name: "something",
            },
          },
        },
        value: [
          {
            category: [6, 7],
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.dom(tree.nodes[0].textElement).hasText("support, something");

      const inputFields = new InputFieldsFromDOM();

      const categorySelector = selectKit(
        `${inputFields.fields.category.selector} .select-kit`
      );

      await categorySelector.expand();
      await categorySelector.deselectItemByValue("6");
      await categorySelector.collapse();

      assert.dom(tree.nodes[0].textElement).hasText("something");

      await click(TOP_LEVEL_ADD_BTN);

      tree.refresh();

      assert.dom(tree.nodes[1].textElement).hasText("category 2");
    });

    test("input fields of type tags which is required", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          identifier: "id",
          properties: {
            required_tags: {
              type: "tags",
              required: true,
            },
            required_tags_with_validations: {
              type: "tags",
              required: true,
              validations: {
                min: 2,
                max: 3,
              },
            },
          },
        },
        value: [
          {
            required_tags: ["gazelle"],
            required_tags_with_validations: ["gazelle", "cat"],
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      let tagSelector = selectKit(
        `${inputFields.fields.required_tags_with_validations.selector} .select-kit`
      );

      assert.strictEqual(tagSelector.header().value(), "gazelle,cat");

      await tagSelector.expand();
      await tagSelector.selectRowByIndex(2);
      await tagSelector.collapse();

      assert.strictEqual(tagSelector.header().value(), "gazelle,cat,dog");

      await tagSelector.expand();
      await tagSelector.deselectItemByName("gazelle");
      await tagSelector.deselectItemByName("cat");
      await tagSelector.deselectItemByName("dog");
      await tagSelector.collapse();

      assert.strictEqual(tagSelector.header().value(), null);

      inputFields.refresh();

      assert
        .dom(inputFields.fields.required_tags_with_validations.errorElement)
        .hasText(
          i18n("admin.customize.theme.schema.fields.tags.at_least", {
            count: 2,
          })
        );

      await tagSelector.expand();
      await tagSelector.selectRowByIndex(1);

      assert.strictEqual(tagSelector.header().value(), "gazelle");

      inputFields.refresh();

      assert
        .dom(inputFields.fields.required_tags_with_validations.errorElement)
        .hasText(
          i18n("admin.customize.theme.schema.fields.tags.at_least", {
            count: 2,
          })
        );

      tagSelector = selectKit(
        `${inputFields.fields.required_tags.selector} .select-kit`
      );

      await tagSelector.expand();
      await tagSelector.deselectItemByName("gazelle");
      await tagSelector.collapse();

      inputFields.refresh();

      assert.dom(inputFields.fields.required_tags.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.tags.at_least", {
          count: 1,
        })
      );
    });

    test("input fields of type groups", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          properties: {
            required_groups: {
              type: "groups",
              required: true,
            },
            groups_with_validations: {
              type: "groups",
              validations: {
                min: 2,
                max: 3,
              },
            },
          },
        },
        value: [
          {
            required_groups: [0, 1],
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const inputFields = new InputFieldsFromDOM();

      let groupsSelector = selectKit(
        `${inputFields.fields.required_groups.selector} .select-kit`
      );

      assert.strictEqual(groupsSelector.header().value(), "0,1");

      await groupsSelector.expand();
      await groupsSelector.deselectItemByValue("0");
      await groupsSelector.deselectItemByValue("1");
      await groupsSelector.collapse();

      inputFields.refresh();

      assert.dom(inputFields.fields.required_groups.errorElement).hasText(
        i18n("admin.customize.theme.schema.fields.groups.at_least", {
          count: 1,
        })
      );

      assert
        .dom(inputFields.fields.groups_with_validations.labelElement)
        .hasText("groups_with_validations");

      groupsSelector = selectKit(
        `${inputFields.fields.groups_with_validations.selector} .select-kit`
      );

      assert.strictEqual(groupsSelector.header().value(), null);

      await groupsSelector.expand();
      await groupsSelector.selectRowByIndex(1);
      await groupsSelector.collapse();

      assert.strictEqual(groupsSelector.header().value(), "1");

      inputFields.refresh();

      assert
        .dom(inputFields.fields.groups_with_validations.errorElement)
        .hasText(
          i18n("admin.customize.theme.schema.fields.groups.at_least", {
            count: 2,
          })
        );

      await groupsSelector.expand();
      await groupsSelector.selectRowByIndex(2);
      await groupsSelector.selectRowByIndex(3);
      await groupsSelector.selectRowByIndex(4);

      assert
        .dom(groupsSelector.error())
        .hasText("You can only select 3 items.");
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
        i18n("admin.customize.theme.schema.back_button", {
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

    test("adding an object to the root list of objects which is empty by default", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          properties: {
            name: {
              type: "string",
            },
          },
        },
        value: [],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      assert.dom(TOP_LEVEL_ADD_BTN).hasText("something");
      await click(TOP_LEVEL_ADD_BTN);

      const tree = new TreeFromDOM();

      assert.dom(tree.nodes[0].textElement).hasText("something 1");

      const inputFields = new InputFieldsFromDOM();

      assert.dom(inputFields.fields.name.labelElement).hasText("name");
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
      tree.refresh();

      assert.strictEqual(tree.nodes.length, 4);
      assert.true(tree.nodes[2].active);
      assert.dom(tree.nodes[2].textElement).hasText("level1 3");
      assert.dom(TOP_LEVEL_ADD_BTN).hasText("level1");
    });

    test("adding an object to a child list of objects when an object has multiple objects properties", async function (assert) {
      const setting = ThemeSettings.create({
        setting: "objects_setting",
        objects_schema: {
          name: "something",
          properties: {
            title: {
              type: "string",
            },
            links: {
              type: "objects",
              schema: {
                name: "link",
                properties: {
                  url: {
                    type: "string",
                  },
                },
              },
            },
            chairs: {
              type: "objects",
              schema: {
                name: "chair",
                properties: {
                  name: {
                    type: "string",
                  },
                },
              },
            },
          },
        },
        value: [
          {
            title: "some title",
          },
        ],
      });

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      await click(tree.nodes[0].addButtons[0]);

      tree.refresh();

      assert.dom(tree.nodes[0].textElement).hasText("link 1");

      const inputFields = new InputFieldsFromDOM();

      assert.dom(inputFields.fields.url.labelElement).hasText("url");
    });

    test("adding an object to a child list of objects", async function (assert) {
      const setting = schemaAndData(1);

      await render(<template>
        <AdminSchemaThemeSettingEditor @themeId="1" @setting={{setting}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.strictEqual(tree.nodes[0].children.length, 2);
      assert.dom(tree.nodes[0].addButtons[0]).hasText("level2");

      await click(tree.nodes[0].addButtons[0]);
      tree.refresh();

      assert.dom(tree.nodes[2].textElement).hasText("level2 3");

      const inputFields = new InputFieldsFromDOM();

      assert.dom(inputFields.fields.name.labelElement).hasText("name");

      await click(TOP_LEVEL_ADD_BTN);
      tree.refresh();

      assert.dom(tree.nodes[3].textElement).hasText("level2 4");
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

      assert.dom(tree.nodes[2].textElement).hasText("level3 3");
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
