import {
  click,
  fillIn,
  findAll,
  render,
  select,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";
import PropertyEngineConfigurator from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/property-engine";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";

module("Integration | Component | workflows property engine", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/svg-sprite/picker-search", () =>
      response(200, [
        { id: "gear", symbol: '<symbol id="gear"></symbol>' },
        { id: "bolt", symbol: '<symbol id="bolt"></symbol>' },
      ])
    );
    pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
      response(200, { variables: [] })
    );
    this.session = new WorkflowEditorSession({
      workflowId: 7,
      lastExecutionRunData: {},
    });
  });

  hooks.afterEach(function () {
    delete I18n.translations[I18n.locale]?.js?.discourse_workflows?.post
      ?.raw_tooltip;
    sinon.restore();
  });

  test("preserves focus for scalar fields while typing", async function (assert) {
    this.setProperties({
      configuration: { title: "" },
      nodeType: "action:topic",
      schema: {
        title: {
          type: "string",
          required: true,
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    await fillIn("input", "Hello");

    assert.dom("input").hasValue("Hello");
    assert.dom("input").isFocused();
  });

  test("renders an inline description and a tooltip independently", async function (assert) {
    I18n.translations[I18n.locale].js.discourse_workflows.post.raw_tooltip =
      "Only visible to the agent";

    this.setProperties({
      configuration: { raw: "" },
      nodeType: "action:post",
      nodeTypes: [{ identifier: "action:post", name: "action:post" }],
      schema: {
        raw: {
          type: "string",
          ui: {
            control: "textarea",
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert
      .dom(".form-kit__container-description")
      .hasText("Raw content for the post");
    assert.dom(".fk-d-tooltip__trigger").exists();

    await click(".fk-d-tooltip__trigger");

    assert
      .dom(".fk-d-tooltip__inner-content")
      .hasText("Only visible to the agent");
  });

  test("hides the tooltip when the label is hidden", async function (assert) {
    I18n.translations[I18n.locale].js.discourse_workflows.post.raw_tooltip =
      "Only visible to the agent";

    this.setProperties({
      configuration: { raw: "" },
      nodeType: "action:post",
      nodeTypes: [{ identifier: "action:post", name: "action:post" }],
      schema: {
        raw: {
          type: "string",
          ui: {
            control: "textarea",
            show_label: false,
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom(".fk-d-tooltip__trigger").doesNotExist();
    assert
      .dom(".form-kit__container-description")
      .hasText("Raw content for the post");
  });

  test("renders checkbox controls from metadata", async function (assert) {
    this.setProperties({
      configuration: {
        category_id: 1,
        include_subcategories: true,
      },
      formApi: null,
      nodeType: "trigger:topic_created",
      schema: {
        category_id: {
          type: "integer",
        },
        include_subcategories: {
          type: "boolean",
          ui: {
            control: "checkbox",
          },
          display_options: {
            show: {
              category_id: [{ condition: { exists: true } }],
            },
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom("input[type='checkbox']").isChecked();

    await click("input[type='checkbox']");

    assert.false(this.formApi.get("include_subcategories"));
  });

  test("renders user seen trigger options as a compact condition group", async function (assert) {
    this.setProperties({
      configuration: {
        group_ids: [],
        trigger_on_first_seen: true,
        trigger_on_not_seen_for_more_than: false,
        not_seen_for_amount: 30,
        not_seen_for_unit: "days",
      },
      formApi: null,
      nodeType: "trigger:user_seen",
      nodeTypes: [
        {
          identifier: "trigger:user_seen",
          name: "trigger:user_seen",
          version: "1.0",
          metadata: {
            groups: [
              { id: 1, name: "support" },
              { id: 2, name: "moderators" },
            ],
          },
        },
      ],
      schema: {
        trigger_conditions: {
          type: "custom",
          ui: {
            control: "user_seen_trigger_options",
          },
        },
        group_ids: {
          type: "multi_options",
          default: [],
          type_options: {
            load_options_method: "groups",
          },
          control_options: {
            filterable: true,
            name_property: "name",
            value_property: "id",
          },
        },
        trigger_on_first_seen: {
          type: "boolean",
          default: true,
          ui: {
            hidden: true,
          },
        },
        trigger_on_not_seen_for_more_than: {
          type: "boolean",
          default: false,
          ui: {
            hidden: true,
          },
        },
        not_seen_for_amount: {
          type: "integer",
          default: 30,
          min: 1,
          ui: {
            hidden: true,
          },
        },
        not_seen_for_unit: {
          type: "options",
          default: "days",
          options: ["hours", "days", "weeks", "months"],
          ui: {
            hidden: true,
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    await waitFor("input[name='trigger_on_first_seen']:checked");

    assert.dom(".form-kit__control-checkbox-description").exists({ count: 2 });
    assert.deepEqual(
      findAll(".form-kit__control-checkbox-description").map((description) =>
        description.textContent.trim()
      ),
      [
        "The user has never been seen before.",
        "Only applies to users with a previous seen date.",
      ],
      "checkbox descriptions render through FormKit"
    );
    assert.dom(".multi-select").exists("the group limiter field renders");
    assert.dom("input[type='checkbox']").exists({ count: 2 });
    assert.dom("input[name='trigger_on_first_seen']").isChecked();
    assert
      .dom("input[name='trigger_on_not_seen_for_more_than']")
      .isNotChecked();
    assert.dom("input[name='not_seen_for_amount']").doesNotExist();
    assert.dom("select[name='not_seen_for_unit']").doesNotExist();

    const groupSelector = selectKit(".multi-select");
    await groupSelector.expand();
    await groupSelector.selectRowByValue("2");

    assert.deepEqual(
      this.formApi.get("group_ids").map(String),
      ["2"],
      "selected group IDs are saved"
    );

    await click("input[name='trigger_on_not_seen_for_more_than']");
    await waitFor("input[name='not_seen_for_amount']");

    assert.true(this.formApi.get("trigger_on_not_seen_for_more_than"));
    assert.strictEqual(this.formApi.get("not_seen_for_amount"), 30);
    assert.strictEqual(this.formApi.get("not_seen_for_unit"), "days");
    assert.dom(".form-kit__container.workflows-user-seen-duration").exists();
    assert.dom("input[name='not_seen_for_amount']").hasValue("30");
    assert.dom("select[name='not_seen_for_unit']").hasValue("days");

    await fillIn("input[name='not_seen_for_amount']", "45");
    await select("select[name='not_seen_for_unit']", "weeks");

    assert.strictEqual(String(this.formApi.get("not_seen_for_amount")), "45");
    assert.strictEqual(this.formApi.get("not_seen_for_unit"), "weeks");
  });

  test("can clear optional category controls", async function (assert) {
    this.setProperties({
      configuration: {
        category_id: 2,
      },
      formApi: null,
      nodeType: "trigger:topic_created",
      schema: {
        category_id: {
          type: "integer",
          required: false,
          ui: {
            control: "category",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const categoryChooser = selectKit(".category-chooser");
    const header = categoryChooser.header();

    assert.strictEqual(header.value(), "2");
    assert.dom(".btn-clear", header.el()).exists();

    await click(header.el().querySelector(".btn-clear"));

    assert.strictEqual(this.formApi.get("category_id"), "");
  });

  test("can clear optional group controls", async function (assert) {
    this.setProperties({
      configuration: {
        group_inbox_id: 2,
      },
      formApi: null,
      nodeType: "trigger:topic_created",
      nodeTypes: [
        {
          identifier: "trigger:topic_created",
          metadata: {
            groups: [
              { id: 1, name: "support" },
              { id: 2, name: "moderators" },
            ],
          },
        },
      ],
      schema: {
        group_inbox_id: {
          type: "integer",
          required: false,
          type_options: {
            load_options_method: "groups",
          },
          ui: {
            control: "group_select",
          },
          control_options: {
            filterable: true,
            name_property: "name",
            value_property: "id",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const groupSelector = selectKit(".combo-box");
    const header = groupSelector.header();

    assert.strictEqual(header.value(), "2");
    assert.dom(".btn-clear", header.el()).exists();

    await click(header.el().querySelector(".btn-clear"));

    assert.strictEqual(this.formApi.get("group_inbox_id"), null);
  });

  test("renders preloaded automatic group option by name", async function (assert) {
    this.setProperties({
      configuration: {
        operation: "check_membership",
        group_id: 14,
      },
      formApi: null,
      node: {
        clientId: "node-1",
        type: "action:group",
        typeVersion: "1.0",
      },
      nodeType: "action:group",
      nodeTypes: [
        {
          identifier: "action:group",
          name: "action:group",
          version: "1.0",
          metadata: {
            groups: [
              { id: 0, name: "everyone" },
              { id: 14, name: "trust_level_2" },
            ],
          },
        },
      ],
      schema: {
        group_id: {
          type: "integer",
          required: true,
          type_options: {
            load_options_method: "groups",
          },
          ui: {
            control: "group_select",
          },
          control_options: {
            filterable: true,
            name_property: "name",
            value_property: "id",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @node={{this.node}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const groupSelector = selectKit(".combo-box");

    assert.strictEqual(groupSelector.header().value(), "14");
    assert.strictEqual(groupSelector.header().label(), "trust_level_2");

    await groupSelector.expand();
    assert
      .dom(".combo-box .select-kit-row[data-value='0']")
      .hasText("everyone");
  });

  test("preserves focus for collection fields while typing", async function (assert) {
    this.setProperties({
      configuration: {
        headers: { values: [{ key: "", value: "" }] },
      },
      nodeType: "action:http_request",
      schema: {
        headers: {
          type: "fixed_collection",
          options: [
            {
              name: "values",
              values: {
                key: {
                  type: "string",
                  required: true,
                },
                value: {
                  type: "string",
                  required: true,
                },
              },
            },
          ],
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    let [keyInput] = findAll(
      ".workflows-property-engine__collection-row input"
    );

    await fillIn(keyInput, "Authorization");

    [keyInput] = findAll(".workflows-property-engine__collection-row input");

    assert.strictEqual(keyInput.value, "Authorization");
    assert.strictEqual(document.activeElement, keyInput);
  });

  test("renders collection options as addable fields", async function (assert) {
    this.setProperties({
      configuration: { updates: {} },
      formApi: null,
      nodeType: "action:user",
      schema: {
        updates: {
          type: "collection",
          type_options: {
            add_optional_field_button_text:
              "discourse_workflows.property_engine.add_field",
          },
          options: [
            {
              name: "title",
              type: "string",
              required: false,
            },
          ],
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom(".workflows-property-engine__collection-row").doesNotExist();
    assert
      .dom(".workflows-property-engine__add-attrs-btn")
      .hasText("Add field");

    await click(".workflows-property-engine__add-attrs-btn");
    await waitFor(".dropdown-menu__item .btn-transparent");
    await click(findAll(".dropdown-menu__item .btn-transparent")[0]);

    assert.dom(".workflows-property-engine__collection-row input").exists();
    assert.dom(".form-kit__container-optional").doesNotExist();

    await fillIn(
      ".workflows-property-engine__collection-row input",
      "Updated title"
    );

    assert.deepEqual(this.formApi.get("updates"), { title: "Updated title" });

    await click(".workflows-property-engine__collection-delete");

    assert.deepEqual(this.formApi.get("updates"), {});
  });

  test("renders collection boolean options inline", async function (assert) {
    this.setProperties({
      configuration: { updates: {} },
      formApi: null,
      nodeType: "action:user",
      schema: {
        updates: {
          type: "collection",
          options: [
            {
              name: "trust_level_locked",
              type: "boolean",
              required: false,
            },
          ],
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    await click(".workflows-property-engine__add-attrs-btn");
    await waitFor(".dropdown-menu__item .btn-transparent");
    await click(findAll(".dropdown-menu__item .btn-transparent")[0]);

    assert
      .dom(".workflows-property-engine__collection-row")
      .hasClass("--inline-control", "boolean rows use the inline row modifier");
    assert
      .dom(
        ".workflows-property-engine__collection-row .d-toggle-switch__checkbox"
      )
      .hasAttribute("aria-checked", "false");
    assert.deepEqual(this.formApi.get("updates"), {
      trust_level_locked: false,
    });

    await click(
      ".workflows-property-engine__collection-row .d-toggle-switch__checkbox"
    );

    assert.deepEqual(this.formApi.get("updates"), {
      trust_level_locked: true,
    });
  });

  test("renders fixed collections with missing group data", async function (assert) {
    this.setProperties({
      configuration: { entries: {} },
      formApi: null,
      nodeType: "action:log",
      schema: {
        entries: {
          type: "fixed_collection",
          type_options: {
            multiple_values: true,
          },
          options: [
            {
              name: "values",
              values: {
                key: {
                  type: "string",
                  required: true,
                  no_data_expression: true,
                },
                value: {
                  type: "string",
                  required: true,
                },
              },
            },
          ],
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom(".workflows-property-engine__collection-row").doesNotExist();

    await click(".btn-default");

    assert.dom(".workflows-property-engine__collection-row").exists();
    assert.strictEqual(this.formApi.get("entries.values").length, 1);
  });

  test("renders condition builder controls inside the property engine", async function (assert) {
    this.setProperties({
      configuration: {
        conditions: [],
      },
      formApi: null,
      node: {
        clientId: "branch",
        type: "condition:if",
        name: "Branch",
      },
      nodes: [
        {
          clientId: "trigger",
          type: "trigger:manual",
          name: "Trigger",
        },
        {
          clientId: "secondary",
          type: "action:http_request",
          name: "Secondary",
        },
        {
          clientId: "branch",
          type: "condition:if",
          name: "Branch",
        },
      ],
      connections: [
        {
          sourceClientId: "trigger",
          targetClientId: "branch",
        },
        {
          sourceClientId: "secondary",
          targetClientId: "branch",
          targetInputIndex: 1,
        },
      ],
      nodeTypes: [],
      nodeType: "condition:if",
      schema: {
        conditions: {
          type: "array",
          ui: {
            control: "condition_builder",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });
    this.session.lastExecutionRunData = {
      Trigger: [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [
                { json: { status: "ok", "topic title": { "post-count": 2 } } },
              ],
              item_count: 1,
            },
          ],
        },
      ],
      Secondary: [
        {
          status: "success",
          outputs: [
            {
              index: 0,
              items: [{ json: { secondary_status: "ok" } }],
              item_count: 1,
            },
          ],
        },
      ],
      Branch: [
        {
          status: "success",
          inputs: [
            {
              index: 0,
              items: [
                { json: { status: "ok", "topic title": { "post-count": 2 } } },
              ],
              item_count: 1,
              source: { node_name: "Trigger", output_index: 0 },
            },
            {
              index: 1,
              items: [{ json: { secondary_status: "ok" } }],
              item_count: 1,
              source: { node_name: "Secondary", output_index: 0 },
            },
          ],
        },
      ],
    };

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @connections={{this.connections}}
            @node={{this.node}}
            @nodes={{this.nodes}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    await click(".workflows-empty-state .btn-primary");

    const conditions = this.formApi.get("conditions");
    assert.strictEqual(conditions.length, 1);
    assert.dom(".workflows-property-engine__collection-row").exists();
    assert
      .dom(
        ".workflows-property-engine__collection-row option[value='$json.status']"
      )
      .exists();
    assert
      .dom(
        '.workflows-property-engine__collection-row option[value=\'$json["topic title"]["post-count"]\']'
      )
      .exists();
    assert
      .dom(
        ".workflows-property-engine__collection-row option[value='$(\"Secondary\").all(0)[$itemIndex].json.secondary_status']"
      )
      .hasText("Secondary.secondary_status");

    await select(
      ".workflows-property-engine__collection-row select",
      '$json["topic title"]["post-count"]'
    );

    assert.strictEqual(
      this.formApi.get("conditions.0.leftValue"),
      '={{ $json["topic title"]["post-count"] }}'
    );
  });

  test("condition builder supports declared integer and array fields", async function (assert) {
    this.setProperties({
      configuration: { conditions: [] },
      formApi: null,
      node: {
        clientId: "branch",
        type: "condition:if",
        name: "Branch",
      },
      nodes: [
        {
          clientId: "trigger",
          type: "trigger:sample",
          typeVersion: "1.0",
          name: "Trigger",
        },
        {
          clientId: "branch",
          type: "condition:if",
          name: "Branch",
        },
      ],
      connections: [
        {
          sourceClientId: "trigger",
          targetClientId: "branch",
        },
      ],
      nodeTypes: [
        {
          name: "trigger:sample",
          versions: {
            "1.0": {
              output_contracts: [
                {
                  schema: {
                    type: "object",
                    properties: {
                      post: {
                        type: "object",
                        properties: {
                          id: { type: "integer" },
                          mixed: { type: ["integer", "string"] },
                          tags: {
                            type: "array",
                            items: { type: "string" },
                          },
                        },
                      },
                    },
                  },
                },
              ],
            },
          },
        },
      ],
      nodeType: "condition:if",
      schema: {
        conditions: {
          type: "array",
          ui: { control: "condition_builder" },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @connections={{this.connections}}
            @node={{this.node}}
            @nodes={{this.nodes}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    await click(".workflows-empty-state .btn-primary");

    assert
      .dom("option[value='$json.post.tags']")
      .exists("offers the array itself for array operators");
    assert
      .dom("option[value='$json.post.tags[0]']")
      .exists("also offers the declared array item path");
    assert
      .dom("option[value='$json.post.mixed']")
      .doesNotExist("does not guess an operator type for union fields");

    await select(
      ".workflows-property-engine__collection-row select",
      "$json.post.id"
    );

    assert.deepEqual(
      this.formApi.get("conditions.0.operator"),
      {
        operation: "equals",
        type: "number",
        singleValue: false,
      },
      "stores the runtime-supported number type for declared integers"
    );
  });

  test("renders webhook URL previews from schema controls", async function (assert) {
    this.setProperties({
      configuration: { path: "my-hook" },
      nodeType: "trigger:webhook",
      schema: {
        path: {
          type: "string",
        },
        url_preview: {
          type: "custom",
          ui: {
            control: "url_preview",
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert
      .dom(".workflows-url-preview code")
      .includesText("/workflows/webhooks/my-hook");
  });

  test("renders form trigger test and production URL controls", async function (assert) {
    sinon.stub(window, "open");
    pretender.post(
      "/admin/plugins/discourse-workflows/workflows/7/form-test-sessions.json",
      (request) => {
        assert.strictEqual(
          request.requestBody,
          "trigger_node_id=trigger-1",
          "posts the selected form trigger node id"
        );
        return response(201, {
          test_url: "/workflows/form-test/test-token",
        });
      }
    );

    this.setProperties({
      configuration: {},
      node: {
        clientId: "trigger-1",
        type: "trigger:form",
        webhookId: "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
      },
      nodeType: "trigger:form",
      schema: {
        url_preview: {
          type: "custom",
          ui: {
            control: "url_preview",
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @node={{this.node}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom(".workflows-url-preview-mode__button").exists({ count: 2 });
    assert
      .dom(".workflows-url-preview code")
      .includesText("/workflows/form/a1b2c3d4-e5f6-7890-abcd-ef0123456789");

    await click(".workflows-url-preview-mode__button:first-child");
    assert
      .dom(".workflows-url-preview code")
      .includesText("Listen for test event");

    await click(".workflows-url-preview");

    assert.true(window.open.calledOnce);
    assert
      .dom(".workflows-url-preview code")
      .includesText("/workflows/form-test/test-token");
  });

  test("renders webhook trigger test and production URL controls", async function (assert) {
    pretender.post(
      "/admin/plugins/discourse-workflows/workflows/7/webhook-test-listeners.json",
      (request) => {
        assert.strictEqual(
          request.requestBody,
          "trigger_node_id=webhook-1",
          "posts the selected webhook trigger node id"
        );
        return response(201, {
          listener_id: "listener-1",
          test_url: "/workflows/webhook-test/listener-1/my-hook",
          expires_at: new Date(Date.now() + 120_000).toISOString(),
        });
      }
    );

    this.setProperties({
      configuration: { path: "my-hook" },
      node: { clientId: "webhook-1", type: "trigger:webhook" },
      nodeType: "trigger:webhook",
      schema: {
        path: {
          type: "string",
        },
        url_preview: {
          type: "custom",
          ui: {
            control: "url_preview",
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @node={{this.node}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom(".workflows-url-preview-mode__button").exists({ count: 2 });
    assert
      .dom(".workflows-url-preview code")
      .includesText("/workflows/webhooks/my-hook");

    await click(".workflows-url-preview-mode__button:first-child");
    assert
      .dom(".workflows-url-preview code")
      .includesText("Listen for test event");

    await click(".workflows-url-preview");

    assert
      .dom(".workflows-url-preview code")
      .includesText("/workflows/webhook-test/listener-1/my-hook");
    assert
      .dom(".workflows-url-preview__status")
      .includesText("Listening for test event");
  });

  test("renders icon fields with the form-kit icon control", async function (assert) {
    this.setProperties({
      configuration: { icon: "gear" },
      formApi: null,
      nodeType: "trigger:topic_admin_button",
      schema: {
        icon: {
          type: "icon",
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom(".form-kit__control-icon").exists();
    assert.dom(".form-kit__control-icon").hasAttribute("data-value", "gear");

    await click(".form-kit__control-icon .d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");
    await click('[data-icon-id="bolt"]');

    assert.dom(".form-kit__control-icon").hasAttribute("data-value", "bolt");

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.strictEqual(this.formApi.get("icon"), "=bolt");
    assert.dom(".workflows-variable-input").exists();
  });

  test("shows expected value hints in dynamic mode", async function (assert) {
    this.setProperties({
      configuration: { channel_id: "2" },
      formApi: null,
      nodeType: "action:send_chat_message",
      schema: {
        channel_id: {
          type: "integer",
          ui: {
            dynamic_value: "chat_channel_id",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom(".workflows-property-engine__dynamic-hint").doesNotExist();

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert
      .dom(".workflows-property-engine__dynamic-hint")
      .hasText("Must resolve to a chat channel ID.");
  });

  test("select fields render with correct initial value", async function (assert) {
    this.setProperties({
      configuration: { combinator: "or" },
      nodeType: "condition:if",
      schema: {
        combinator: {
          type: "options",
          options: ["and", "or"],
          default: "and",
          no_data_expression: true,
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert.dom("select").hasValue("or");
  });

  test("renders combo boxes from metadata and applies option patches", async function (assert) {
    this.setProperties({
      configuration: {
        agent_force_default_llm: true,
        agent_id: 2,
        agent_name: "",
        llm_model_id: 99,
      },
      formApi: null,
      nodeType: "action:ai_agent",
      nodeTypes: [
        {
          identifier: "action:ai_agent",
          metadata: {
            agents: [
              { id: 1, name: "Support Bot", force_default_llm: false },
              { id: 2, name: "Helper Bot", force_default_llm: true },
            ],
            i18n_prefix: "discourse_ai.discourse_workflows",
          },
        },
      ],
      schema: {
        agent_id: {
          type: "integer",
          required: true,
          type_options: {
            load_options_method: "agents",
          },
          no_data_expression: true,
          ui: {
            control: "combo_box",
          },
          control_options: {
            filterable: true,
            name_property: "name",
            none: "discourse_ai.discourse_workflows.ai_agent.select_agent",
            resets: ["llm_model_id"],
            set_from_option: {
              agent_force_default_llm: "force_default_llm",
              agent_name: "name",
            },
            value_property: "id",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const selector = selectKit(".combo-box");
    assert.strictEqual(selector.header().value(), "2");
    assert.strictEqual(selector.header().label(), "Helper Bot");

    await selector.expand();
    await selector.selectRowByValue("1");

    assert.strictEqual(String(this.formApi.get("agent_id")), "1");
    assert.false(this.formApi.get("agent_force_default_llm"));
    assert.strictEqual(this.formApi.get("agent_name"), "Support Bot");
    assert.strictEqual(this.formApi.get("llm_model_id"), null);
  });

  test("renders combo box actions with the selected field value as a route model", async function (assert) {
    const router = this.owner.lookup("service:router");
    const transitionTo = sinon.stub(router, "transitionTo");

    this.setProperties({
      configuration: {
        workflow_id: null,
      },
      nodeType: "action:workflow_call",
      nodeTypes: [
        {
          identifier: "action:workflow_call",
          metadata: {
            callable_workflows: [{ id: 8, name: "Child workflow" }],
          },
        },
      ],
      schema: {
        workflow_id: {
          type: "integer",
          required: true,
          type_options: {
            load_options_method: "callable_workflows",
          },
          no_data_expression: true,
          ui: {
            control: "combo_box",
          },
          control_options: {
            action_icon: "up-right-from-square",
            action_label: "discourse_workflows.workflow_call.open_workflow",
            action_route: "adminPlugins.show.discourse-workflows.show",
            action_route_models: [{ source: "field_value" }],
            name_property: "name",
            value_property: "id",
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    assert
      .dom(".workflows-property-engine__select-with-action > .btn")
      .doesNotExist();

    const selector = selectKit(".combo-box");
    await selector.expand();
    await selector.selectRowByValue("8");

    assert
      .dom(".workflows-property-engine__select-with-action > .btn")
      .hasText("Open workflow");

    await click(".workflows-property-engine__select-with-action > .btn");

    assert.true(
      transitionTo.calledWith(
        "adminPlugins.show.discourse-workflows.show",
        sinon.match((value) => String(value) === "8", "selected workflow id")
      )
    );
  });

  test("applies option patches from remote combo box options", async function (assert) {
    const requests = [];
    pretender.post(
      "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
      (request) => {
        const body = JSON.parse(request.requestBody);
        requests.push(body);

        return response([
          {
            id: 1,
            name: "Support Bot",
            force_default_llm: false,
            resolved_llm_name: "Default LLM",
          },
        ]);
      }
    );

    this.setProperties({
      configuration: {
        agent_force_default_llm: true,
        agent_id: null,
        agent_name: "",
        agent_resolved_llm_name: "",
        llm_model_id: 99,
      },
      formApi: null,
      node: {
        clientId: "node-1",
        type: "action:ai_agent",
        typeVersion: "1.0",
      },
      nodeType: "action:ai_agent",
      nodeTypes: [
        {
          identifier: "action:ai_agent",
          name: "action:ai_agent",
          version: "1.0",
        },
      ],
      schema: {
        agent_id: {
          type: "integer",
          required: true,
          type_options: {
            load_options_method: "agents",
          },
          no_data_expression: true,
          ui: {
            control: "combo_box",
          },
          control_options: {
            filterable: true,
            name_property: "name",
            resets: ["llm_model_id"],
            set_from_option: {
              agent_force_default_llm: "force_default_llm",
              agent_name: "name",
              agent_resolved_llm_name: "resolved_llm_name",
            },
            value_property: "id",
          },
        },
        agent_force_default_llm: {
          type: "boolean",
        },
        agent_name: {
          type: "string",
        },
        agent_resolved_llm_name: {
          type: "string",
        },
        llm_model_id: {
          type: "integer",
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @node={{this.node}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const selector = selectKit(".combo-box");
    await selector.expand();
    await waitFor(".combo-box .select-kit-row[data-value='1']");
    await selector.selectRowByValue("1");

    assert.strictEqual(String(this.formApi.get("agent_id")), "1");
    assert.false(this.formApi.get("agent_force_default_llm"));
    assert.strictEqual(this.formApi.get("agent_name"), "Support Bot");
    assert.strictEqual(
      this.formApi.get("agent_resolved_llm_name"),
      "Default LLM"
    );
    assert.strictEqual(this.formApi.get("llm_model_id"), null);
    assert.true(requests.length >= 1);
    assert.strictEqual(requests[0].methodName, "agents");
  });

  test("renders combo box dynamic none labels from configuration", async function (assert) {
    this.setProperties({
      configuration: {
        agent_resolved_llm_name: "Workflow LLM",
        llm_model_id: null,
      },
      nodeType: "action:ai_agent",
      nodeTypes: [
        {
          identifier: "action:ai_agent",
          metadata: {
            llm_models: [{ id: 1, name: "Override LLM" }],
          },
        },
      ],
      schema: {
        llm_model_id: {
          type: "integer",
          required: false,
          type_options: {
            load_options_method: "llm_models",
          },
          no_data_expression: true,
          ui: {
            control: "combo_box",
          },
          control_options: {
            name_property: "name",
            none: "discourse_ai.discourse_workflows.ai_agent.llm_model_default",
            none_label_field: "agent_resolved_llm_name",
            none_label_i18n_key:
              "discourse_ai.discourse_workflows.ai_agent.llm_model_default_with_name",
            value_property: "id",
          },
        },
      },
    });

    await render(
      <template>
        <Form @data={{this.configuration}} as |form transientData|>
          <PropertyEngineConfigurator
            @form={{form}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const selector = selectKit(".combo-box");

    assert.strictEqual(
      selector.header().label(),
      "Use agent default (Workflow LLM)"
    );
  });

  test("renders remote multi-select options from load options", async function (assert) {
    const requests = [];
    pretender.post(
      "/admin/plugins/discourse-workflows/dynamic-node-parameters/options.json",
      (request) => {
        const body = JSON.parse(request.requestBody);
        requests.push(body);

        return response([{ id: "foo", name: "foo" }]);
      }
    );

    this.setProperties({
      configuration: {
        operation: "get",
        topic_id: "21",
        custom_field_names: [],
      },
      formApi: null,
      node: {
        clientId: "node-1",
        type: "action:topic",
        typeVersion: "1.0",
      },
      nodeType: "action:topic",
      nodeTypes: [
        {
          identifier: "action:topic",
          name: "action:topic",
          version: "1.0",
          metadata: {
            topic_custom_fields: [{ id: "system", name: "system" }],
          },
        },
      ],
      schema: {
        custom_field_names: {
          type: "multi_options",
          options: [],
          type_options: {
            load_options_depends_on: ["operation", "topic_id"],
            load_options_method: "topic_custom_fields",
          },
          control_options: {
            filterable: true,
            name_property: "name",
            value_property: "id",
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @node={{this.node}}
            @nodeType={{this.nodeType}}
            @nodeTypes={{this.nodeTypes}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const selector = selectKit(".multi-select");
    await selector.expand();
    await waitFor(".multi-select .select-kit-row[data-value='foo']");
    await selector.selectRowByValue("foo");

    assert.deepEqual(this.formApi.get("custom_field_names"), ["foo"]);
    assert.strictEqual(selector.header().label(), "foo");
    assert.true(requests.length >= 1);
    assert.strictEqual(requests[0].methodName, "topic_custom_fields");
    assert.deepEqual(requests[0].currentNodeParameters, {
      operation: "get",
      topic_id: "21",
      custom_field_names: [],
    });
  });

  test("multi_input fields accept arbitrary ids and convert between fixed and dynamic", async function (assert) {
    this.setProperties({
      configuration: { upload_ids: [] },
      formApi: null,
      nodeType: "action:ai_agent",
      schema: {
        upload_ids: {
          type: "array",
          required: false,
          ui: {
            control: "multi_input",
            expression: true,
          },
        },
      },
      registerApi: (api) => {
        this.set("formApi", api);
      },
    });

    await render(
      <template>
        <Form
          @data={{this.configuration}}
          @onRegisterApi={{this.registerApi}}
          as |form transientData|
        >
          <PropertyEngineConfigurator
            @form={{form}}
            @formApi={{this.formApi}}
            @configuration={{transientData}}
            @nodeType={{this.nodeType}}
            @schema={{this.schema}}
            @session={{this.session}}
          />
        </Form>
      </template>
    );

    const selector = selectKit(".multi-select");

    await selector.expand();
    await selector.fillInFilter("12");
    await selector.selectRowByValue("12");
    await selector.fillInFilter("34");
    await selector.selectRowByValue("34");

    assert.deepEqual(
      this.formApi.get("upload_ids"),
      ["12", "34"],
      "stores entered ids"
    );

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.strictEqual(
      this.formApi.get("upload_ids"),
      '={{ ["12","34"] }}',
      "converts the fixed list into a dynamic expression"
    );

    await click(
      '.workflows-property-engine__mode-control input[value="plain"]'
    );

    assert.deepEqual(
      this.formApi.get("upload_ids"),
      ["12", "34"],
      "converts the dynamic expression back into a fixed list"
    );
  });
});
