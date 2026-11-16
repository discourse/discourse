import { click, findAll, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";
import DataTableColumns from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/data-table-columns";

const COLUMN = ".workflows-data-table-columns__column";
const ADD_MENU = ".workflows-property-engine__add-attrs-btn";

const METADATA = {
  data_tables: [
    {
      id: 1,
      name: "Contacts",
      columns: [
        { name: "id", type: "number", reserved: true },
        { name: "title", type: "string" },
        { name: "score", type: "number" },
        { name: "active", type: "boolean" },
      ],
    },
  ],
};

const NODE_DEFINITION = { identifier: "action:data_table", version: "1.0" };

const EMPTY_PLACEHOLDER = i18n(
  "discourse_workflows.data_table_node.empty_column_placeholder"
);
const EMPTY_EXPRESSION_ERROR = i18n(
  "discourse_workflows.parameter_field.empty_expression",
  { plain: i18n("discourse_workflows.parameter_field.plain") }
);

function column(name) {
  return `${COLUMN}[data-column-name="${name}"]`;
}

function renderColumns(
  context,
  columns,
  { metadata = METADATA, nodeDefinition } = {}
) {
  context.setProperties({
    configuration: { data_table_id: 1, columns },
    formApi: null,
    metadata,
    nodeDefinition,
    registerApi: (api) => context.set("formApi", api),
  });

  return render(
    <template>
      <Form
        @data={{context.configuration}}
        @onRegisterApi={{context.registerApi}}
        as |form transientData|
      >
        <DataTableColumns
          @configuration={{transientData}}
          @fieldName="columns"
          @form={{form}}
          @formApi={{context.formApi}}
          @label="Columns"
          @metadata={{context.metadata}}
          @nodeDefinition={{context.nodeDefinition}}
        />
      </Form>
    </template>
  );
}

function menuItems() {
  return findAll(".dropdown-menu__item .btn-transparent");
}

function menuText(element) {
  return element.textContent.trim();
}

async function openAddMenu() {
  await click(ADD_MENU);
  await waitFor(".dropdown-menu__item .btn-transparent");
}

async function addColumn(name) {
  await openAddMenu();
  await click(menuItems().find((element) => menuText(element) === name));
}

module("Integration | Component | DataTableColumns", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response(200, { variables: [] })
    );
  });

  test("renders only the columns present in the configuration", async function (assert) {
    await renderColumns(this, { title: "Hello", score: null });

    assert
      .dom(COLUMN)
      .exists({ count: 2 }, "only present columns are rendered");
    assert.form().field("columns.title").hasValue("Hello");
    assert
      .dom(`${column("score")} input`)
      .hasAttribute("placeholder", EMPTY_PLACEHOLDER, "NULL shows as empty");
    assert.dom(column("active")).doesNotExist("absent columns are hidden");
  });

  test("adds a single column from the menu", async function (assert) {
    await renderColumns(this, {});

    assert.dom(COLUMN).doesNotExist("starts with no columns");

    await addColumn("score");

    assert.dom(column("score")).exists("the added column is rendered");
    assert.deepEqual(this.formApi.get("columns"), { score: null });

    await openAddMenu();

    assert.deepEqual(
      menuItems().map(menuText),
      [
        i18n("discourse_workflows.data_table_node.add_all_columns"),
        "title",
        "active",
      ],
      "the menu lists only the columns not added yet"
    );
  });

  test("adds all remaining columns at once", async function (assert) {
    await renderColumns(this, { title: "Hello" });

    await openAddMenu();
    await click(".workflows-property-engine__add-all");

    assert.deepEqual(this.formApi.get("columns"), {
      title: "Hello",
      score: null,
      active: false,
    });
    assert.dom(COLUMN).exists({ count: 3 });
    assert.dom(ADD_MENU).doesNotExist("nothing left to add");
  });

  test("removing a column deletes its key", async function (assert) {
    await renderColumns(this, { title: "Hello", score: 3 });

    await click(
      `${column("title")} .workflows-property-engine__collection-delete`
    );

    assert.deepEqual(
      this.formApi.get("columns"),
      { score: 3 },
      "the key is removed rather than set to null"
    );
    assert.dom(column("title")).doesNotExist();
  });

  test("clearing a column keeps it as an explicit NULL", async function (assert) {
    await renderColumns(this, { title: "Hello" });

    await formKit().field("columns.title").fillIn("");

    assert.true(
      Object.hasOwn(this.formApi.get("columns"), "title"),
      "the key stays present"
    );
    assert.strictEqual(this.formApi.get("columns.title"), null);
    assert
      .dom(`${column("title")} input`)
      .hasAttribute("placeholder", EMPTY_PLACEHOLDER);
  });

  test("boolean columns can be unset by removing them", async function (assert) {
    await renderColumns(this, { active: true });

    assert
      .dom(column("active"))
      .hasClass("--inline-control", "booleans use the inline row");

    await click(
      `${column("active")} .workflows-property-engine__collection-delete`
    );

    assert.deepEqual(this.formApi.get("columns"), {});
  });

  test("shows removable notices for columns that can't be written", async function (assert) {
    await renderColumns(this, { renamed: "x", id: 5, title: "Hello" });

    assert.dom(column("id")).hasClass("--missing");
    assert.dom(column("renamed")).hasClass("--missing");
    assert
      .dom(`${column("renamed")} .workflows-data-table-columns__missing`)
      .includesText("renamed");
    assert.dom(`${column("renamed")} input`).doesNotExist();

    await click(
      `${column("renamed")} .workflows-property-engine__collection-delete`
    );

    assert.deepEqual(this.formApi.get("columns"), { id: 5, title: "Hello" });
  });

  test("validates dynamic expressions on text and boolean columns", async function (assert) {
    await renderColumns(this, {
      title: "={{ }}",
      active: "=",
      score: "={{ $json.score }}",
    });

    await this.formApi.submit();

    assert.form().field("columns.title").hasError(EMPTY_EXPRESSION_ERROR);
    assert.form().field("columns.active").hasError(EMPTY_EXPRESSION_ERROR);
    assert.form().field("columns.score").hasNoErrors();
    assert
      .dom(column("active"))
      .doesNotHaveClass(
        "--inline-control",
        "dynamic booleans use the full row"
      );
  });

  test("switching an empty expression back to plain keeps NULL", async function (assert) {
    await renderColumns(this, { title: "=" });

    assert
      .dom(`${column("title")} [placeholder="${EMPTY_PLACEHOLDER}"]`)
      .doesNotExist("no NULL placeholder in dynamic mode");

    await click(
      `${column("title")} .d-segmented-control__input[value='plain']`
    );

    assert.strictEqual(this.formApi.get("columns.title"), null);
    assert
      .dom(`${column("title")} input.form-kit__control-input`)
      .hasAttribute("placeholder", EMPTY_PLACEHOLDER);
  });

  test("leaves a whole-object expression untouched", async function (assert) {
    await renderColumns(this, "={{ $json }}");

    assert.dom(".workflows-data-table-columns").doesNotExist();
    assert.strictEqual(this.formApi.get("columns"), "={{ $json }}");
  });

  test("waits for the data tables before rendering the columns", async function (assert) {
    let release;
    const released = new Promise((resolve) => (release = resolve));

    pretender.post(
      "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
      async () => {
        await released;
        return response(METADATA.data_tables);
      }
    );

    const renderPromise = renderColumns(
      this,
      { title: "Hello" },
      { metadata: null, nodeDefinition: NODE_DEFINITION }
    );

    await waitFor("form");

    assert
      .dom(".workflows-data-table-columns")
      .doesNotExist("nothing renders while loading");
    assert.dom(`${COLUMN}.--missing`).doesNotExist();

    release();
    await renderPromise;
    await settled();

    assert.dom(column("title")).exists();
    assert.dom(column("title")).doesNotHaveClass("--missing");
  });

  test("keeps saved columns editable when the data table can't be resolved", async function (assert) {
    pretender.post(
      "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
      () => response([])
    );

    await renderColumns(
      this,
      { title: "Hello" },
      { metadata: null, nodeDefinition: NODE_DEFINITION }
    );

    assert.dom(column("title")).doesNotHaveClass("--missing");
    assert.form().field("columns.title").hasValue("Hello");

    await click(
      `${column("title")} .workflows-property-engine__collection-delete`
    );

    assert.deepEqual(this.formApi.get("columns"), {});
  });
});
