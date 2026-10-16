import {
  click,
  fillIn,
  findAll,
  focus,
  render,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import AdminSchemaSettingEditor from "discourse/admin/components/schema-setting/editor";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import schemaAndData, {
  objectsSetting,
} from "discourse/tests/fixtures/theme-setting-schema-data";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

const tree = {
  get nodes() {
    return findAll(
      ".schema-setting-editor__tree .schema-setting-editor__tree-node.--parent"
    ).map((element, index) => ({
      element,
      active: element.classList.contains("--active"),
      textElement: element.querySelector(
        ".schema-setting-editor__tree-node-text"
      ),
      children: findAll(
        `.schema-setting-editor__tree-node.--child[data-test-parent-index="${index}"]`
      ).map((child) => ({
        element: child,
        textElement: child.querySelector(
          ".schema-setting-editor__tree-node-text"
        ),
      })),
      addButtons: findAll(
        `.schema-setting-editor__tree-add-button.--child[data-test-parent-index="${index}"]`
      ),
    }));
  },
};

const inputFields = {
  get count() {
    return findAll(".schema-field").length;
  },

  get fields() {
    return Object.fromEntries(
      findAll(".schema-field").map((field) => [
        field.dataset.name,
        {
          labelElement: field.querySelector(".schema-field__label"),
          inputElement: field.querySelector(".schema-field__input").children[0],
          countElement: field.querySelector(".schema-field__input-count"),
          errorElement: field.querySelector(".schema-field__input-error"),
          descriptionElement: field.querySelector(
            ".schema-field__input-description"
          ),
          selector: `.schema-field[data-name="${field.dataset.name}"]`,
        },
      ])
    );
  },
};

const TOP_LEVEL_ADD_BTN = ".schema-setting-editor__tree-add-button.--root";
const REMOVE_ITEM_BTN = ".schema-setting-editor__remove-btn";
const MOVE_UP_BTN = ".schema-setting-editor__move-up-btn";
const MOVE_DOWN_BTN = ".schema-setting-editor__move-down-btn";
const SAVE_BTN = ".schema-setting-editor__footer .btn-primary";

function renderEditor(setting) {
  return render(
    <template>
      <DialogHolder />
      <AdminSchemaSettingEditor
        @id="1"
        @routeToRedirect="adminCustomizeThemes.show"
        @schema={{setting.objects_schema}}
        @setting={{setting}}
      />
    </template>
  );
}

async function captureSavedValue(owner) {
  sinon.stub(owner.lookup("service:router"), "transitionTo");

  let savedValue;
  pretender.put("/admin/themes/1/setting", (request) => {
    savedValue = JSON.parse(parsePostData(request.requestBody).value);
    return response({});
  });

  await click(SAVE_BTN);

  return savedValue;
}

module(
  "Integration | Admin | Themes | Component | SchemaSetting | Editor",
  function (hooks) {
    setupRenderingTest(hooks);

    test("allows navigating through multiple levels of nesting", async function (assert) {
      await renderEditor(schemaAndData(1));

      assert.strictEqual(tree.nodes.length, 3);
      assert.true(tree.nodes[0].active, "the first node is active by default");
      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.strictEqual(tree.nodes[0].children.length, 2);
      assert.dom(tree.nodes[0].children[0].textElement).hasText("child 1-1");
      assert.dom(tree.nodes[0].children[1].textElement).hasText("child 1-2");

      assert.false(tree.nodes[1].active);
      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.strictEqual(
        tree.nodes[1].children.length,
        0,
        "only the active node's children are shown"
      );

      await click(tree.nodes[1].element);

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

      assert.strictEqual(tree.nodes.length, 4);

      assert.dom(inputFields.fields.name.labelElement).hasText("Level 2 Label");
      assert
        .dom(inputFields.fields.name.descriptionElement)
        .hasText("Description for level 2");

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

    test("the back button navigates to the previous level", async function (assert) {
      await renderEditor(schemaAndData(1));

      assert.dom(".--back-btn").doesNotExist("hidden at the root level");

      await click(tree.nodes[1].element);
      await click(tree.nodes[1].children[1].element);

      assert
        .dom(".--back-btn")
        .hasText(
          i18n("admin.customize.schema.back_button", { name: "item 2" })
        );

      await click(tree.nodes[1].children[0].element);

      assert
        .dom(".--back-btn")
        .hasText(
          i18n("admin.customize.schema.back_button", { name: "child 2-2" })
        );

      await click(".--back-btn");

      assert.dom(tree.nodes[1].textElement).hasText("child 2-2");
      assert.true(
        tree.nodes[1].active,
        "the previously active child is restored"
      );
      assert
        .dom(".--back-btn")
        .hasText(
          i18n("admin.customize.schema.back_button", { name: "item 2" })
        );

      await click(tree.nodes[0].element);
      await click(".--back-btn");

      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.true(
        tree.nodes[1].active,
        "the previously active item is restored"
      );
      assert.dom(".--back-btn").doesNotExist("hidden again at the root level");
    });

    test("input fields are rendered even if they're not present in the data", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.id.inputElement).hasValue("bu1");
      assert.dom(inputFields.fields.name.inputElement).hasValue("Big U");

      await click(tree.nodes[1].element);

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.id.inputElement).hasValue("fi2");
      assert.dom(inputFields.fields.name.inputElement).hasNoValue();
    });

    test("input fields for items at different levels", async function (assert) {
      await renderEditor(schemaAndData(2));

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.name.labelElement).hasText("name");
      assert.dom(inputFields.fields.icon.labelElement).hasText("icon");

      assert.dom(inputFields.fields.name.inputElement).hasValue("nice section");
      assert.dom(inputFields.fields.icon.inputElement).hasValue("arrow");

      await click(tree.nodes[1].element);

      assert.strictEqual(inputFields.count, 2);
      assert.dom(inputFields.fields.name.inputElement).hasValue("cool section");
      assert.dom(inputFields.fields.icon.inputElement).hasValue("bell");

      await click(tree.nodes[1].children[1].element);

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
      const setting = objectsSetting({
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

      await renderEditor(setting);

      assert.dom(inputFields.fields.id.labelElement).hasText("id*");
      assert.dom(inputFields.fields.id.countElement).hasText("3/5");

      await fillIn(inputFields.fields.id.inputElement, "1");

      assert.dom(inputFields.fields.id.countElement).hasText("1/5");

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.schema.fields.string.too_short", {
          count: 2,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "");

      assert.dom(inputFields.fields.id.countElement).hasText("0/5");

      assert
        .dom(inputFields.fields.id.errorElement)
        .hasText(i18n("admin.customize.schema.fields.required"));
    });

    test("input fields of type integer", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      assert.dom(inputFields.fields.id.inputElement).hasValue("6");

      assert
        .dom(inputFields.fields.id.inputElement)
        .hasAttribute("type", "number");

      await fillIn(inputFields.fields.id.inputElement, "922229");

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.schema.fields.number.too_large", {
          count: 10,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "0");

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.schema.fields.number.too_small", {
          count: 5,
        })
      );

      await fillIn(inputFields.fields.id.inputElement, "");

      assert
        .dom(inputFields.fields.id.errorElement)
        .hasText(i18n("admin.customize.schema.fields.required"));
    });

    test("input fields of type float", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      assert.dom(inputFields.fields.id.inputElement).hasValue("6.5");

      await fillIn(inputFields.fields.id.inputElement, "0.2");

      assert.dom(inputFields.fields.id.errorElement).hasText(
        i18n("admin.customize.schema.fields.number.too_small", {
          count: 5.5,
        }),
        "fractional input is parsed as a float"
      );
    });

    test("input fields of type boolean", async function (assert) {
      await renderEditor(schemaAndData(3));

      assert.dom(inputFields.fields.boolean_field.inputElement).isChecked();

      await click(inputFields.fields.boolean_field.inputElement);
      await click(tree.nodes[1].element);

      assert.dom(inputFields.fields.boolean_field.inputElement).isNotChecked();

      await click(tree.nodes[0].element);

      assert.dom(inputFields.fields.boolean_field.inputElement).isNotChecked();
    });

    test("stores the defaults of required boolean and enum fields", async function (assert) {
      await renderEditor(
        objectsSetting({
          objects_schema: {
            name: "something",
            properties: {
              required_boolean_field: { type: "boolean", required: true },
              optional_boolean_field: { type: "boolean" },
              optional_enum_field: {
                type: "enum",
                default: "cool",
                choices: ["nice", "cool", "awesome"],
              },
              required_enum_field: {
                type: "enum",
                required: true,
                default: "awesome",
                choices: ["nice", "cool", "awesome"],
              },
            },
          },
          value: [{}, { required_boolean_field: true }],
        })
      );

      await click(TOP_LEVEL_ADD_BTN);

      assert.deepEqual(
        await captureSavedValue(this.owner),
        [
          { required_boolean_field: false, required_enum_field: "awesome" },
          { required_boolean_field: true, required_enum_field: "awesome" },
          { required_boolean_field: false, required_enum_field: "awesome" },
        ],
        "existing and new items store required defaults, keep stored values and leave optional fields unset"
      );
    });

    test("input fields of type enum", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      const enumSelector = selectKit(
        `${inputFields.fields.enum_field.selector} .select-kit`
      );

      assert.strictEqual(enumSelector.header().value(), null);

      await enumSelector.expand();
      await enumSelector.selectRowByValue("cool");
      await click(enumSelector.clearButton());

      assert.strictEqual(
        enumSelector.header().value(),
        null,
        "optional enums can be cleared"
      );

      const requiredEnumSelector = selectKit(
        `${inputFields.fields.required_enum_field.selector} .select-kit`
      );

      assert.strictEqual(requiredEnumSelector.header().value(), "awesome");
      assert.strictEqual(requiredEnumSelector.header().label(), "awesome");

      await requiredEnumSelector.expand();
      await requiredEnumSelector.selectRowByValue("nice");

      assert.strictEqual(requiredEnumSelector.header().value(), "nice");
      assert.strictEqual(
        requiredEnumSelector.clearButton(),
        null,
        "required enums can't be cleared"
      );

      await click(tree.nodes[1].element);
      assert.strictEqual(requiredEnumSelector.header().value(), "cool");

      await click(tree.nodes[0].element);
      assert.strictEqual(requiredEnumSelector.header().value(), "nice");

      await click(TOP_LEVEL_ADD_BTN);

      assert.strictEqual(requiredEnumSelector.header().value(), "awesome");
    });

    test("input fields of type icon", async function (assert) {
      pretender.get("/svg-sprite/picker-search", () =>
        response({
          icons: [
            { id: "gamepad", name: "gamepad" },
            { id: "heart", name: "heart" },
          ],
          has_more: false,
        })
      );

      const setting = objectsSetting({
        objects_schema: {
          name: "something",
          properties: {
            icon_field: {
              type: "icon",
            },
            required_icon_field: {
              type: "icon",
              required: true,
            },
          },
        },
        value: [{ required_icon_field: "heart" }],
      });

      await renderEditor(setting);

      assert
        .dom(
          `${inputFields.fields.required_icon_field.selector} .d-icon-grid-picker`
        )
        .hasAttribute("data-value", "heart");

      assert
        .dom(`${inputFields.fields.icon_field.selector} .d-icon-grid-picker`)
        .doesNotHaveAttribute("data-value");

      await click(
        `${inputFields.fields.icon_field.selector} .d-icon-grid-picker-trigger`
      );
      await waitFor("[data-icon-id='gamepad']");
      await click("[data-icon-id='gamepad']");

      assert
        .dom(`${inputFields.fields.icon_field.selector} .d-icon-grid-picker`)
        .hasAttribute("data-value", "gamepad");

      assert.deepEqual(
        await captureSavedValue(this.owner),
        [{ required_icon_field: "heart", icon_field: "gamepad" }],
        "the picked icon is stored"
      );
    });

    test("input fields of type categories that is not required with min and max validations", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      const categorySelector = selectKit(
        `${inputFields.fields.not_required_category.selector} .select-kit`
      );

      assert.strictEqual(categorySelector.header().value(), null);

      await categorySelector.expand();
      await categorySelector.selectRowByIndex(1);
      await categorySelector.collapse();

      assert.dom(inputFields.fields.not_required_category.errorElement).hasText(
        i18n("admin.customize.schema.fields.categories.at_least", {
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

      assert
        .dom(inputFields.fields.not_required_category.errorElement)
        .doesNotExist();
    });

    test("input fields of type categories", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      let categorySelector = selectKit(
        `${inputFields.fields.required_category.selector} .select-kit`
      );

      assert.strictEqual(categorySelector.header().value(), "6");

      await categorySelector.expand();
      await categorySelector.deselectItemByValue("6");
      await categorySelector.collapse();

      assert.dom(inputFields.fields.required_category.errorElement).hasText(
        i18n("admin.customize.schema.fields.categories.at_least", {
          count: 1,
        })
      );
    });

    test("input field of type categories with schema's identifier set to categories field", async function (assert) {
      const setting = objectsSetting({
        objects_schema: {
          name: "category",
          identifier: "category",
          properties: {
            children: {
              type: "objects",
              schema: {
                name: "child",
                identifier: "category",
                properties: { category: { type: "categories" } },
              },
            },
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
            children: [{ category: [7] }],
          },
        ],
      });

      await renderEditor(setting);

      assert.dom(tree.nodes[0].textElement).hasText("support, something");

      assert
        .dom(tree.nodes[0].children[0].textElement)
        .hasText("something", "the child uses its own category identifier");
      await click(tree.nodes[0].children[0].element);
      assert.dom(".--back-btn").hasText(
        i18n("admin.customize.schema.back_button", {
          name: "support, something",
        }),
        "the back button uses the parent's category identifier"
      );
      await click(".--back-btn");

      const categorySelector = selectKit(
        `${inputFields.fields.category.selector} .select-kit`
      );

      await categorySelector.expand();
      await categorySelector.deselectItemByValue("6");
      await categorySelector.collapse();

      assert.dom(tree.nodes[0].textElement).hasText("something");

      await click(TOP_LEVEL_ADD_BTN);

      assert.dom(tree.nodes[1].textElement).hasText("category 2");
    });

    test("input fields of type tags which is required", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      let tagSelector = selectKit(
        `${inputFields.fields.required_tags_with_validations.selector} .select-kit`
      );

      assert.strictEqual(tagSelector.header().name(), "gazelle,cat");

      await tagSelector.expand();
      await tagSelector.selectRowByIndex(2);
      await tagSelector.collapse();

      assert.strictEqual(tagSelector.header().name(), "gazelle,cat,dog");

      await tagSelector.expand();
      await tagSelector.deselectItemByName("gazelle");
      await tagSelector.deselectItemByName("cat");
      await tagSelector.deselectItemByName("dog");
      await tagSelector.collapse();

      assert.strictEqual(tagSelector.header().value(), null);

      assert
        .dom(inputFields.fields.required_tags_with_validations.errorElement)
        .hasText(
          i18n("admin.customize.schema.fields.tags.at_least", {
            count: 2,
          })
        );

      await tagSelector.expand();
      await tagSelector.selectRowByIndex(1);

      assert.strictEqual(tagSelector.header().name(), "gazelle");

      assert
        .dom(inputFields.fields.required_tags_with_validations.errorElement)
        .hasText(
          i18n("admin.customize.schema.fields.tags.at_least", {
            count: 2,
          })
        );

      tagSelector = selectKit(
        `${inputFields.fields.required_tags.selector} .select-kit`
      );

      await tagSelector.expand();
      await tagSelector.deselectItemByName("gazelle");
      await tagSelector.collapse();

      assert.dom(inputFields.fields.required_tags.errorElement).hasText(
        i18n("admin.customize.schema.fields.tags.at_least", {
          count: 1,
        })
      );
    });

    test("input fields of type groups", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      let groupsSelector = selectKit(
        `${inputFields.fields.required_groups.selector} .select-kit`
      );

      assert.strictEqual(groupsSelector.header().value(), "0,1");

      await groupsSelector.expand();
      await groupsSelector.deselectItemByValue("0");
      await groupsSelector.deselectItemByValue("1");
      await groupsSelector.collapse();

      assert.dom(inputFields.fields.required_groups.errorElement).hasText(
        i18n("admin.customize.schema.fields.groups.at_least", {
          count: 1,
        })
      );

      groupsSelector = selectKit(
        `${inputFields.fields.groups_with_validations.selector} .select-kit`
      );

      assert.strictEqual(groupsSelector.header().value(), null);

      await groupsSelector.expand();
      await groupsSelector.selectRowByIndex(1);
      await groupsSelector.collapse();

      assert.strictEqual(groupsSelector.header().value(), "1");

      assert
        .dom(inputFields.fields.groups_with_validations.errorElement)
        .hasText(
          i18n("admin.customize.schema.fields.groups.at_least", {
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

    test("input fields of type groups filter disallowed groups", async function (assert) {
      this.site.groups = [
        { id: 0, name: "everyone" },
        { id: 1, name: "admins" },
        { id: 2, name: "moderators" },
      ];

      const setting = objectsSetting({
        objects_schema: {
          name: "something",
          properties: {
            group_ids: {
              type: "groups",
              disallowed_groups: "0|1",
            },
          },
        },
        value: [
          {
            group_ids: [],
          },
        ],
      });

      await renderEditor(setting);

      const groupsSelector = selectKit(
        `${inputFields.fields.group_ids.selector} .select-kit`
      );

      await groupsSelector.expand();

      assert.false(
        groupsSelector.rowByValue("0").exists(),
        "everyone is not in the list"
      );
      assert.false(
        groupsSelector.rowByValue("1").exists(),
        "admins is not in the list"
      );
      assert.true(
        groupsSelector.rowByValue("2").exists(),
        "moderators is in the list"
      );
    });

    test("generic identifier is used when identifier is not specified in the schema", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      assert.dom(tree.nodes[0].textElement).hasText("section 1");
      assert.dom(tree.nodes[0].children[0].textElement).hasText("link 1");
      assert.dom(tree.nodes[0].children[1].textElement).hasText("link 2");
      assert.dom(tree.nodes[1].textElement).hasText("section 2");

      await click(tree.nodes[1].element);

      assert.dom(tree.nodes[1].children[0].textElement).hasText("link 1");

      await click(tree.nodes[0].element);
      await click(REMOVE_ITEM_BTN);

      assert
        .dom(tree.nodes[0].textElement)
        .hasText("section 1", "the remaining item is renumbered");
    });

    test("identifier field instantly updates in the navigation tree when the input field is changed", async function (assert) {
      const setting = schemaAndData(2);

      await renderEditor(setting);

      await focus(inputFields.fields.name.inputElement);
      await fillIn(
        inputFields.fields.name.inputElement,
        "nice section is really nice"
      );

      assert
        .dom(inputFields.fields.name.inputElement)
        .isFocused("editing preserves the input and its focus");
      assert
        .dom(tree.nodes[0].textElement)
        .hasText("nice section is really nice");

      assert.strictEqual(
        setting.value[0].name,
        "nice section",
        "unsaved edits do not mutate the setting"
      );

      await click(tree.nodes[0].children[0].element);

      await fillIn(
        inputFields.fields.text.inputElement,
        "Security instead of Privacy"
      );

      assert
        .dom(tree.nodes[0].textElement)
        .hasText("Security instead of Privacy");
    });

    test("edits are remembered when navigating between levels", async function (assert) {
      await renderEditor(schemaAndData(2));

      await fillIn(
        inputFields.fields.name.inputElement,
        "changed section name"
      );

      await click(tree.nodes[1].element);

      await fillIn(
        inputFields.fields.name.inputElement,
        "cool section is no longer cool"
      );

      await click(tree.nodes[1].children[1].element);

      assert.dom(".--back-btn").hasText(
        i18n("admin.customize.schema.back_button", {
          name: "cool section is no longer cool",
        })
      );

      await fillIn(inputFields.fields.text.inputElement, "Talk to us");
      await click(".--back-btn");

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

      assert.dom(inputFields.fields.text.inputElement).hasValue("Talk to us");
    });

    test("adding an object to the root list of objects which is empty by default", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      assert.dom(TOP_LEVEL_ADD_BTN).hasText("something");

      await click(TOP_LEVEL_ADD_BTN);

      assert.dom(tree.nodes[0].textElement).hasText("something 1");

      assert.dom(inputFields.fields.name.labelElement).hasText("name");
    });

    test("adding an object to a child list of objects when an object has multiple objects properties", async function (assert) {
      const setting = objectsSetting({
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

      await renderEditor(setting);

      await click(tree.nodes[0].addButtons[0]);

      assert.dom(tree.nodes[0].textElement).hasText("link 1");

      assert.dom(inputFields.fields.url.labelElement).hasText("url");
    });

    test("adding objects to nested lists of objects", async function (assert) {
      await renderEditor(schemaAndData(1));

      assert.dom(tree.nodes[0].addButtons[0]).hasText("level2");

      await click(tree.nodes[0].addButtons[0]);

      assert.dom(TOP_LEVEL_ADD_BTN).hasText("level2");
      assert.dom(tree.nodes[2].textElement).hasText("level2 3");
      assert.dom(inputFields.fields.name.labelElement).hasText("Level 2 Label");
      assert.dom(tree.nodes[2].addButtons[0]).hasText("level3");
      assert.strictEqual(tree.nodes[2].children.length, 0);

      await click(tree.nodes[2].addButtons[0]);
      await click(TOP_LEVEL_ADD_BTN);

      assert.strictEqual(
        tree.nodes.length,
        3,
        "both grandchildren and the add button are visible"
      );

      await fillIn(inputFields.fields.name.inputElement, "Second grandchild");

      assert
        .dom(tree.nodes[1].textElement)
        .hasText(
          "Second grandchild",
          "the new grandchild is editable and updates its title"
        );
    });

    test("removing an object from the root list of objects", async function (assert) {
      await renderEditor(schemaAndData(1));

      assert.strictEqual(tree.nodes.length, 3);
      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("item 1");

      await click(tree.nodes[1].element);
      await click(REMOVE_ITEM_BTN);

      assert.strictEqual(tree.nodes.length, 2);
      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert
        .dom(inputFields.fields.name.inputElement)
        .hasValue("item 1", "the previous item becomes active");

      await click(REMOVE_ITEM_BTN);

      assert.strictEqual(tree.nodes.length, 1);
      assert.strictEqual(inputFields.count, 0);
      assert.dom(REMOVE_ITEM_BTN).doesNotExist();
      assert.dom(TOP_LEVEL_ADD_BTN).hasText("level1");
    });

    test("removing an object with delete warning from the root list of objects", async function (assert) {
      await renderEditor(schemaAndData(4));
      await click(REMOVE_ITEM_BTN);
      await click(".dialog-footer .btn-default");

      assert.strictEqual(tree.nodes.length, 3, "cancelling keeps the item");

      await click(REMOVE_ITEM_BTN);

      assert.dom("#dialog-title").hasText("Delete warning title");
      assert.dom(".dialog-body").includesText("Delete warning message");

      await click(".dialog-footer .btn-danger");

      assert.strictEqual(tree.nodes.length, 2);
      assert.dom(tree.nodes[0].textElement).hasText("item 2");
    });

    test("navigating 1 level deep and removing an object from the child list of objects", async function (assert) {
      await renderEditor(schemaAndData(1));

      await click(tree.nodes[0].children[0].element);

      assert.strictEqual(tree.nodes.length, 3);
      assert.dom(tree.nodes[0].textElement).hasText("child 1-1");
      assert.dom(tree.nodes[1].textElement).hasText("child 1-2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("child 1-1");

      await click(REMOVE_ITEM_BTN);

      assert.strictEqual(tree.nodes.length, 2);
      assert.dom(tree.nodes[0].textElement).hasText("child 1-2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("child 1-2");

      await click(REMOVE_ITEM_BTN);

      assert.strictEqual(tree.nodes.length, 3);
      assert.strictEqual(tree.nodes[0].children.length, 0);

      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.dom(tree.nodes[1].textElement).hasText("item 2");
      assert.dom(inputFields.fields.name.inputElement).hasValue("item 1");
      assert
        .dom(".--back-btn")
        .doesNotExist(
          "removing the last child navigates back to the parent level"
        );
    });

    test("move buttons reorder items", async function (assert) {
      await renderEditor(schemaAndData(1));

      assert.dom(MOVE_UP_BTN).isDisabled("the first item can't move up");
      assert.dom(MOVE_DOWN_BTN).isNotDisabled();

      await click(tree.nodes[1].element);

      assert.dom(MOVE_UP_BTN).isNotDisabled();
      assert.dom(MOVE_DOWN_BTN).isDisabled("the last item can't move down");

      await click(MOVE_UP_BTN);

      assert.dom(tree.nodes[0].textElement).hasText("item 2");
      assert.dom(tree.nodes[1].textElement).hasText("item 1");

      await click(MOVE_DOWN_BTN);

      assert.dom(tree.nodes[0].textElement).hasText("item 1");
      assert.dom(tree.nodes[1].textElement).hasText("item 2");

      await click(tree.nodes[1].children[1].element);
      await click(MOVE_UP_BTN);

      assert
        .dom(tree.nodes[0].textElement)
        .hasText("child 2-2", "nested items can be moved");
      assert.dom(tree.nodes[1].textElement).hasText("child 2-1");
    });

    test("multiple upload fields have unique IDs", async function (assert) {
      await renderEditor(
        objectsSetting({
          objects_schema: {
            name: "something",
            properties: {
              first_upload: { type: "upload" },
              second_upload: { type: "upload" },
            },
          },
          value: [{}],
        })
      );

      assert
        .dom("#schema-field-upload-objects_setting-first_upload")
        .exists("the first upload field has an id based on its name");
      assert
        .dom("#schema-field-upload-objects_setting-second_upload")
        .exists("the second upload field has an id based on its name");
    });
  }
);
