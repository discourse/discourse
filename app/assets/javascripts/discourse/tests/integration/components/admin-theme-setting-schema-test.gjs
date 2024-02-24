import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";
import AdminThemeSettingSchema from "admin/components/admin-theme-setting-schema";

const schema = {
  name: "level1",
  identifier: "name",
  properties: {
    name: {
      type: "string",
    },
    children: {
      type: "objects",
      schema: {
        name: "level2",
        identifier: "name",
        properties: {
          name: {
            type: "string",
          },
          grandchildren: {
            type: "objects",
            schema: {
              name: "level3",
              identifier: "name",
              properties: {
                name: {
                  type: "string",
                },
              },
            },
          },
        },
      },
    },
  },
};
const data = [
  {
    name: "item 1",
    children: [
      {
        name: "child 1-1",
        grandchildren: [
          {
            name: "grandchild 1-1-1",
          },
          {
            name: "grandchild 1-1-2",
          },
        ],
      },
      {
        name: "child 1-2",
        grandchildren: [
          {
            name: "grandchild 1-2-1",
          },
        ],
      },
    ],
  },
  {
    name: "item 2",
    children: [
      {
        name: "child 2-1",
        grandchildren: [
          {
            name: "grandchild 2-1-1",
          },
          {
            name: "grandchild 2-1-2",
          },
        ],
      },
      {
        name: "child 2-2",
        grandchildren: [
          {
            name: "grandchild 2-2-1",
          },
          {
            name: "grandchild 2-2-2",
          },
          {
            name: "grandchild 2-2-3",
          },
          {
            name: "grandchild 2-2-4",
          },
        ],
      },
      {
        name: "child 2-3",
        grandchildren: [],
      },
    ],
  },
];

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

module(
  "Integration | Component | admin-theme-settings-schema",
  function (hooks) {
    setupRenderingTest(hooks);

    test("activates the first node by default", async function (assert) {
      await render(<template>
        <AdminThemeSettingSchema @schema={{schema}} @data={{data}} />
      </template>);

      const tree = new TreeFromDOM();

      assert.strictEqual(tree.nodes.length, 2);
      assert.true(tree.nodes[0].active, "the first node is active");
      assert.false(tree.nodes[1].active, "other nodes are not active");
    });

    test("renders the 2nd level of nested items for the active item only", async function (assert) {
      await render(<template>
        <AdminThemeSettingSchema @schema={{schema}} @data={{data}} />
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
      await render(<template>
        <AdminThemeSettingSchema @schema={{schema}} @data={{data}} />
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
      await render(<template>
        <AdminThemeSettingSchema @schema={{schema}} @data={{data}} />
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
      await render(<template>
        <AdminThemeSettingSchema @schema={{schema}} @data={{data}} />
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
      await render(<template>
        <AdminThemeSettingSchema @schema={{schema}} @data={{data}} />
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
  }
);
