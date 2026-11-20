import { tracked } from "@glimmer/tracking";
import {
  click,
  fillIn,
  find,
  findAll,
  render,
  select,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import Form from "discourse/components/form";
import emojisFixtures from "discourse/tests/fixtures/emojis-fixtures";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import emojiPicker from "discourse/tests/helpers/emoji-picker-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { NO_VALUE_OPTION } from "discourse/ui-kit/d-native-select";
import I18n, { i18n } from "discourse-i18n";
import PropertyEngineConfigurator from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/property-engine";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";

async function renderEngine(context, { withFormApi = false } = {}) {
  const formApi = tracked(undefined);
  const registerApi = withFormApi ? (api) => (formApi.value = api) : undefined;

  await render(
    <template>
      <Form
        @data={{context.configuration}}
        @onRegisterApi={{registerApi}}
        as |form transientData|
      >
        <PropertyEngineConfigurator
          @configuration={{transientData}}
          @connections={{context.connections}}
          @form={{form}}
          @formApi={{formApi.value}}
          @node={{context.node}}
          @nodes={{context.nodes}}
          @nodeType={{context.nodeType}}
          @nodeTypes={{context.nodeTypes}}
          @onChange={{context.onChange}}
          @schema={{context.schema}}
          @session={{context.session}}
        />
      </Form>
    </template>
  );

  return formApi.value;
}

module("Integration | Component | workflows property engine", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/svg-sprite/picker-search", () =>
      response(200, {
        icons: [
          { id: "gear", symbol: '<symbol id="gear"></symbol>' },
          { id: "bolt", symbol: '<symbol id="bolt"></symbol>' },
        ],
        has_more: false,
      })
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
    this.configuration = { title: "" };
    this.nodeType = "action:topic";
    this.schema = {
      title: {
        type: "string",
        required: true,
      },
    };

    await renderEngine(this);

    await fillIn("input", "Hello");

    assert.dom("input").hasValue("Hello");
    assert.dom("input").isFocused();
  });

  test("picks emojis for emoji fields", async function (assert) {
    pretender.get("/emojis.json", () =>
      response(emojisFixtures["/emojis.json"])
    );
    pretender.get("/emojis/search-aliases.json", () => response([]));

    this.configuration = { reaction: null };
    this.nodeType = "action:topic";
    this.schema = {
      reaction: {
        type: "emoji",
        no_data_expression: true,
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    await click(".btn-emoji");
    await emojiPicker(".emoji-picker").select("grinning");

    assert.strictEqual(formApi.get("reaction"), "grinning");
  });

  test("validates optional integer fields that do not support expressions", async function (assert) {
    this.configuration = { post_number: "" };
    this.nodeType = "trigger:post_button";
    this.schema = {
      post_number: {
        type: "integer",
        required: false,
        min: 1,
        no_data_expression: true,
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    await formApi.submit();
    assert
      .form()
      .field("post_number")
      .hasNoErrors("the optional field is valid while blank");

    await fillIn("input[name='post_number']", "1.5");
    await formApi.submit();
    assert
      .form()
      .field("post_number")
      .hasError(
        i18n("form_kit.errors.not_an_integer"),
        "a fractional value shows the integer validation error"
      );

    await fillIn("input[name='post_number']", "2");
    await formApi.submit();
    assert
      .form()
      .field("post_number")
      .hasNoErrors("an integer value clears the validation error");
  });

  test("expression-enabled integer fields accept expressions", async function (assert) {
    this.configuration = { post_number: "={{ $json.post_number }}" };
    this.nodeType = "trigger:post_button";
    this.schema = {
      post_number: {
        type: "integer",
        min: 1,
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    assert.dom(".workflows-variable-input").includesText("post_number");

    await formApi.submit();
    assert
      .form()
      .field("post_number")
      .hasNoErrors("the expression is not treated as a literal integer");
  });

  test("renders an inline description and a tooltip independently", async function (assert) {
    I18n.translations[I18n.locale].js.discourse_workflows.post.raw_tooltip =
      "Only visible to the agent";

    this.configuration = { raw: "" };
    this.nodeType = "action:post";
    this.nodeTypes = [{ identifier: "action:post", name: "action:post" }];
    this.schema = {
      raw: {
        type: "string",
        ui: {
          control: "textarea",
        },
      },
    };

    await renderEngine(this);

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

    this.configuration = { raw: "" };
    this.nodeType = "action:post";
    this.nodeTypes = [{ identifier: "action:post", name: "action:post" }];
    this.schema = {
      raw: {
        type: "string",
        ui: {
          control: "textarea",
          show_label: false,
        },
      },
    };

    await renderEngine(this);

    assert.dom(".fk-d-tooltip__trigger").doesNotExist();
    assert
      .dom(".form-kit__container-description")
      .hasText("Raw content for the post");
  });

  test("renders checkbox controls from metadata", async function (assert) {
    this.configuration = {
      category_ids: [1],
      include_subcategories: true,
    };
    this.nodeType = "trigger:topic_created";
    this.schema = {
      category_ids: {
        type: "array",
        ui: {
          control: "category",
          multiple: true,
        },
      },
      include_subcategories: {
        type: "boolean",
        ui: {
          control: "checkbox",
        },
        display_options: {
          show: {
            category_ids: [{ condition: { exists: true } }],
          },
        },
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    assert.dom("input[type='checkbox']").isChecked();

    await click("input[type='checkbox']");

    assert.false(formApi.get("include_subcategories"));
  });

  test("hides fields conditioned on a category list when it is empty", async function (assert) {
    this.configuration = {
      category_ids: [],
      include_subcategories: true,
    };
    this.nodeType = "trigger:topic_created";
    this.schema = {
      category_ids: {
        type: "array",
        ui: {
          control: "category",
          multiple: true,
        },
      },
      include_subcategories: {
        type: "boolean",
        ui: {
          control: "checkbox",
        },
        display_options: {
          show: {
            category_ids: [{ condition: { exists: true } }],
          },
        },
      },
    };

    await renderEngine(this);

    assert.dom(".category-selector").exists();
    assert.dom("input[type='checkbox']").doesNotExist();
  });

  test("renders user seen trigger options as a compact condition group", async function (assert) {
    this.configuration = {
      group_ids: [],
      trigger_on_first_seen: true,
      trigger_on_not_seen_for_more_than: false,
      not_seen_for_amount: 30,
      not_seen_for_unit: "days",
    };
    this.nodeType = "trigger:user_seen";
    this.nodeTypes = [
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
    ];
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

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
      formApi.get("group_ids").map(String),
      ["2"],
      "selected group IDs are saved"
    );

    await click("input[name='trigger_on_not_seen_for_more_than']");
    await waitFor("input[name='not_seen_for_amount']");

    assert.true(formApi.get("trigger_on_not_seen_for_more_than"));
    assert.strictEqual(formApi.get("not_seen_for_amount"), 30);
    assert.strictEqual(formApi.get("not_seen_for_unit"), "days");
    assert.dom(".form-kit__container.workflows-user-seen-duration").exists();
    assert.dom("input[name='not_seen_for_amount']").hasValue("30");
    assert.dom("select[name='not_seen_for_unit']").hasValue("days");

    await fillIn("input[name='not_seen_for_amount']", "45");
    await select("select[name='not_seen_for_unit']", "weeks");

    assert.strictEqual(String(formApi.get("not_seen_for_amount")), "45");
    assert.strictEqual(formApi.get("not_seen_for_unit"), "weeks");
  });

  test("can clear optional category controls", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = true;

    this.configuration = {
      category_id: 2,
    };
    this.nodeType = "trigger:topic_created";
    this.schema = {
      category_id: {
        type: "integer",
        required: false,
        ui: {
          control: "category",
        },
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const categoryChooser = selectKit(".category-chooser");
    const header = categoryChooser.header();

    assert.strictEqual(header.value(), "2");
    assert.dom(".btn-clear", header.el()).exists();

    await click(header.el().querySelector(".btn-clear"));

    assert.strictEqual(formApi.get("category_id"), "");
  });

  test("hides the clear button on category controls when uncategorized topics are disallowed", async function (assert) {
    this.siteSettings.allow_uncategorized_topics = false;

    this.configuration = {
      category_id: 2,
    };
    this.nodeType = "trigger:topic_created";
    this.schema = {
      category_id: {
        type: "integer",
        required: false,
        ui: {
          control: "category",
        },
      },
    };

    await renderEngine(this, { withFormApi: true });

    const categoryChooser = selectKit(".category-chooser");
    const header = categoryChooser.header();

    assert.strictEqual(header.value(), "2");
    assert
      .dom(".btn-clear", header.el())
      .doesNotExist("clearing would move the topic to uncategorized");
  });

  test("can clear optional group controls", async function (assert) {
    this.configuration = {
      group_inbox_id: 2,
    };
    this.nodeType = "trigger:topic_created";
    this.nodeTypes = [
      {
        identifier: "trigger:topic_created",
        metadata: {
          groups: [
            { id: 1, name: "support" },
            { id: 2, name: "moderators" },
          ],
        },
      },
    ];
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const groupSelector = selectKit(".combo-box");
    const header = groupSelector.header();

    assert.strictEqual(header.value(), "2");
    assert.dom(".btn-clear", header.el()).exists();

    await click(header.el().querySelector(".btn-clear"));

    assert.strictEqual(formApi.get("group_inbox_id"), null);
  });

  test("renders preloaded automatic group option by name", async function (assert) {
    this.configuration = {
      operation: "check_membership",
      group_id: 14,
    };
    this.node = {
      clientId: "node-1",
      type: "action:group",
      typeVersion: "1.0",
    };
    this.nodeType = "action:group";
    this.nodeTypes = [
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
    ];
    this.schema = {
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
    };

    await renderEngine(this, { withFormApi: true });

    const groupSelector = selectKit(".combo-box");

    assert.strictEqual(groupSelector.header().value(), "14");
    assert.strictEqual(groupSelector.header().label(), "trust_level_2");

    await groupSelector.expand();
    assert
      .dom(".combo-box .select-kit-row[data-value='0']")
      .hasText("everyone");
  });

  test("preserves focus for collection fields while typing", async function (assert) {
    this.configuration = {
      headers: { values: [{ key: "", value: "" }] },
    };
    this.nodeType = "action:http_request";
    this.schema = {
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
    };

    await renderEngine(this);

    let [keyInput] = findAll(
      ".workflows-property-engine__collection-row input"
    );

    await fillIn(keyInput, "Authorization");

    [keyInput] = findAll(".workflows-property-engine__collection-row input");

    assert.strictEqual(keyInput.value, "Authorization");
    assert.strictEqual(document.activeElement, keyInput);
  });

  test("renders collection options as addable fields", async function (assert) {
    this.configuration = { updates: {} };
    this.nodeType = "action:user";
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

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

    assert.deepEqual(formApi.get("updates"), { title: "Updated title" });

    await click(".workflows-property-engine__collection-delete");

    assert.deepEqual(formApi.get("updates"), {});
  });

  test("renders collection boolean options inline", async function (assert) {
    this.configuration = { updates: {} };
    this.nodeType = "action:user";
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

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
    assert.deepEqual(formApi.get("updates"), {
      trust_level_locked: false,
    });

    await click(
      ".workflows-property-engine__collection-row .d-toggle-switch__checkbox"
    );

    assert.deepEqual(formApi.get("updates"), {
      trust_level_locked: true,
    });
  });

  test("renders fixed collections with missing group data", async function (assert) {
    this.configuration = { entries: {} };
    this.nodeType = "action:log";
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    assert.dom(".workflows-property-engine__collection-row").doesNotExist();

    await click(".btn-default");

    assert.dom(".workflows-property-engine__collection-row").exists();
    assert.strictEqual(formApi.get("entries.values").length, 1);
  });

  test("edits optional fixed collection styles and icons without expressions", async function (assert) {
    this.configuration = {
      buttons: {
        values: [{ label: "Approve", value: "approve" }],
      },
    };
    this.nodeType = "action:chat_approval";
    this.schema = {
      buttons: {
        type: "fixed_collection",
        options: [
          {
            name: "values",
            values: {
              label: {
                type: "string",
                required: true,
                no_data_expression: true,
              },
              value: {
                type: "string",
                required: true,
                no_data_expression: true,
              },
              style: {
                type: "options",
                required: false,
                options: [
                  "default",
                  "primary",
                  "danger",
                  "success",
                  "flat",
                  "transparent",
                ],
                no_data_expression: true,
                control_options: {
                  none: "none_placeholder",
                },
              },
              icon: {
                type: "icon",
                required: false,
                no_data_expression: true,
              },
            },
          },
        ],
        type_options: {
          multiple_values: true,
        },
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const row = ".workflows-property-engine__collection-row";
    const styleField = '[data-name="buttons.values.0.style"]';
    const iconField = '[data-name="buttons.values.0.icon"]';

    assert.dom(styleField).exists("the optional style is always shown");
    assert.dom(iconField).exists("the optional icon is always shown");
    assert
      .dom(`${row} .workflows-property-engine__mode-control`)
      .doesNotExist("the button fields do not offer expression controls");

    await select(`${styleField} select`, "primary");

    assert.strictEqual(
      formApi.get("buttons.values.0.style"),
      "primary",
      "the nested style is selected"
    );
    assert
      .dom(`${styleField} option[value="${NO_VALUE_OPTION}"]`)
      .hasText(
        i18n("none_placeholder"),
        "the opt-in no-value option remains available after selection"
      );

    await click(`${iconField} .d-icon-grid-picker-trigger`);
    await waitFor("[data-icon-id='gear']");
    await click("[data-icon-id='gear']");

    assert.strictEqual(
      formApi.get("buttons.values.0.icon"),
      "gear",
      "the nested icon is selected"
    );
    assert
      .dom(`${iconField} .d-icon-grid-picker__clear`)
      .exists("the optional icon can be cleared");

    await select(`${styleField} select`, NO_VALUE_OPTION);
    await click(`${iconField} .d-icon-grid-picker__clear`);

    assert.strictEqual(
      formApi.get("buttons.values.0.style"),
      null,
      "the nested style is cleared"
    );
    assert.strictEqual(
      formApi.get("buttons.values.0.icon"),
      null,
      "the nested icon is cleared"
    );
  });

  test("reorders sortable fixed collection items", async function (assert) {
    this.configuration = {
      buttons: {
        values: [
          { label: "Approve", value: "approve" },
          { label: "Deny", value: "deny" },
        ],
      },
    };
    this.nodeType = "action:chat_approval";
    this.onChange = sinon.spy();
    this.schema = {
      buttons: {
        type: "fixed_collection",
        type_options: {
          multiple_values: true,
          sortable: true,
        },
        options: [
          {
            name: "values",
            values: {
              label: {
                type: "string",
                required: true,
                no_data_expression: true,
              },
              value: {
                type: "string",
                required: true,
                no_data_expression: true,
              },
            },
          },
        ],
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const moveItemSelector = (direction, position) =>
      `[aria-label="${i18n(
        `discourse_workflows.property_engine.move_item_${direction}`,
        { position }
      )}"]`;
    const moveButtons = (direction) => [
      find(moveItemSelector(direction, 1)),
      find(moveItemSelector(direction, 2)),
    ];
    let moveUpButtons = moveButtons("up");
    let moveDownButtons = moveButtons("down");

    assert
      .dom(".workflows-property-engine__collection-move")
      .exists({ count: 4 }, "each item has reorder controls");
    assert.dom(moveUpButtons[0]).isDisabled("the first item cannot move up");
    assert.dom(moveDownButtons[1]).isDisabled("the last item cannot move down");

    await click(moveUpButtons[1]);

    assert.deepEqual(
      formApi.get("buttons.values"),
      [
        { label: "Deny", value: "deny" },
        { label: "Approve", value: "approve" },
      ],
      "moving up updates the collection value"
    );
    assert
      .dom(findAll(".workflows-property-engine__collection-row input")[0])
      .hasValue("Deny", "the reordered value renders in the first row");
    assert.true(this.onChange.calledOnce, "the editor observes the reorder");

    moveDownButtons = moveButtons("down");
    await click(moveDownButtons[0]);

    assert.deepEqual(
      formApi.get("buttons.values"),
      [
        { label: "Approve", value: "approve" },
        { label: "Deny", value: "deny" },
      ],
      "moving down updates the collection value"
    );
    assert.true(this.onChange.calledTwice, "the editor observes each reorder");

    moveUpButtons = moveButtons("up");
    moveDownButtons = moveButtons("down");
    assert.dom(moveUpButtons[0]).isDisabled("the first boundary is restored");
    assert.dom(moveDownButtons[1]).isDisabled("the last boundary is restored");
  });

  test("does not add reorder controls to non-sortable fixed collections", async function (assert) {
    this.configuration = {
      entries: {
        values: [{ key: "first" }, { key: "second" }],
      },
    };
    this.nodeType = "action:log";
    this.schema = {
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
            },
          },
        ],
      },
    };

    await renderEngine(this);

    assert
      .dom(".workflows-property-engine__collection-order-controls")
      .doesNotExist("reordering remains opt-in");
    assert
      .dom(".workflows-property-engine__collection-delete")
      .exists({ count: 2 }, "existing collection controls remain unchanged");
  });

  test("labels fixed collection remove buttons for items without a name", async function (assert) {
    this.configuration = { entries: { values: [{ aggregation: "count" }] } };
    this.nodeType = "action:log";
    this.schema = {
      entries: {
        type: "fixed_collection",
        type_options: {
          multiple_values: true,
        },
        options: [
          {
            name: "values",
            values: {
              aggregation: {
                type: "string",
                required: true,
                no_data_expression: true,
              },
            },
          },
        ],
      },
    };

    await renderEngine(this);

    assert
      .dom(".workflows-property-engine__collection-delete")
      .hasAria("label", i18n("discourse_workflows.property_engine.remove_item"))
      .hasAttribute(
        "title",
        i18n("discourse_workflows.property_engine.remove_item")
      );
  });

  test("labels fixed collection remove buttons with the item name", async function (assert) {
    this.configuration = { entries: { values: [{ name: "Alpha" }] } };
    this.nodeType = "action:log";
    this.schema = {
      entries: {
        type: "fixed_collection",
        type_options: {
          multiple_values: true,
        },
        options: [
          {
            name: "values",
            values: {
              name: {
                type: "string",
                required: true,
                no_data_expression: true,
              },
            },
          },
        ],
      },
    };

    await renderEngine(this);

    assert.dom(".workflows-property-engine__collection-delete").hasAria(
      "label",
      i18n("discourse_workflows.property_engine.remove_assignment", {
        name: "Alpha",
      })
    );
  });

  test("only titles the fixed collection add button when a maximum exists", async function (assert) {
    this.configuration = { entries: { values: [] }, capped: { values: [] } };
    this.nodeType = "action:log";
    this.schema = {
      entries: {
        type: "fixed_collection",
        type_options: {
          multiple_values: true,
        },
        options: [
          {
            name: "values",
            values: {
              key: { type: "string", required: true },
            },
          },
        ],
      },
      capped: {
        type: "fixed_collection",
        max_items: 1,
        type_options: {
          multiple_values: true,
        },
        options: [
          {
            name: "values",
            values: {
              key: { type: "string", required: true },
            },
          },
        ],
      },
    };

    await renderEngine(this);

    const addButtons = findAll(".form-kit__section .btn-default");

    assert.dom(addButtons[0]).doesNotHaveAttribute("title");
    assert.dom(addButtons[1]).hasAttribute(
      "title",
      i18n("discourse_workflows.property_engine.max_items_reached", {
        count: 1,
      })
    );
  });

  test("renders condition builder controls inside the property engine", async function (assert) {
    this.configuration = {
      conditions: [],
    };
    this.node = {
      clientId: "branch",
      type: "condition:if",
      name: "Branch",
    };
    this.nodes = [
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
    ];
    this.connections = [
      {
        sourceClientId: "trigger",
        targetClientId: "branch",
      },
      {
        sourceClientId: "secondary",
        targetClientId: "branch",
        targetInputIndex: 1,
      },
    ];
    this.nodeTypes = [];
    this.nodeType = "condition:if";
    this.schema = {
      conditions: {
        type: "array",
        ui: {
          control: "condition_builder",
        },
      },
    };
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

    const formApi = await renderEngine(this, { withFormApi: true });

    await click(".workflows-empty-state .btn-primary");

    const conditions = formApi.get("conditions");
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
      formApi.get("conditions.0.leftValue"),
      '={{ $json["topic title"]["post-count"] }}'
    );
  });

  test("condition builder supports declared integer and array fields", async function (assert) {
    this.session.outputSchemas = {
      trigger: [
        {
          type: "object",
          properties: {
            post: {
              type: "object",
              properties: {
                id: { type: "integer" },
                mixed: { type: ["integer", "string"] },
                tags: { type: "array", items: { type: "string" } },
              },
            },
          },
        },
      ],
    };
    this.configuration = { conditions: [] };
    this.node = {
      clientId: "branch",
      type: "condition:if",
      name: "Branch",
    };
    this.nodes = [
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
    ];
    this.connections = [
      {
        sourceClientId: "trigger",
        targetClientId: "branch",
      },
    ];
    this.nodeType = "condition:if";
    this.schema = {
      conditions: {
        type: "array",
        ui: { control: "condition_builder" },
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

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
      formApi.get("conditions.0.operator"),
      {
        operation: "equals",
        type: "number",
        singleValue: false,
      },
      "stores the runtime-supported number type for declared integers"
    );
  });

  test("renders webhook URL previews from schema controls", async function (assert) {
    this.configuration = { path: "my-hook" };
    this.nodeType = "trigger:webhook";
    this.schema = {
      path: {
        type: "string",
      },
      url_preview: {
        type: "custom",
        ui: {
          control: "url_preview",
        },
      },
    };

    await renderEngine(this);

    assert
      .dom(".workflows-url-preview code")
      .includesText("/workflows/webhooks/my-hook");
  });

  test("summarize placeholders use server output keys and add/remove notify changes", async function (assert) {
    this.session.outputSchemas = {
      "summarize-1": [
        {
          type: "object",
          properties: { region: {}, sum_a_total: {}, sum_b_total: {} },
        },
      ],
    };
    this.configuration = {
      fields_to_summarize: {
        values: [
          { aggregation: "sum", field: "a.total", output_field_name: "" },
          { aggregation: "sum", field: "b.total", output_field_name: "" },
        ],
      },
    };
    this.node = { clientId: "summarize-1", type: "action:summarize" };
    this.nodeType = "action:summarize";
    this.onChange = sinon.spy();
    this.schema = {
      fields_to_summarize: {
        type: "fixed_collection",
        ui: { control: "summarize_aggregations" },
        type_options: { multiple_values: true },
        options: [
          {
            name: "values",
            values: {
              aggregation: {
                type: "options",
                options: ["sum"],
                no_data_expression: true,
              },
              field: { type: "string", no_data_expression: true },
              output_field_name: {
                type: "string",
                no_data_expression: true,
              },
            },
          },
        ],
      },
    };

    await renderEngine(this);

    assert.deepEqual(
      findAll(".workflows-summarize-row__control--derived input").map(
        (input) => input.placeholder
      ),
      ["sum_a_total", "sum_b_total"]
    );

    await click(".workflows-property-engine__collection-delete");
    assert.true(this.onChange.calledOnce);

    await click("button.btn-default:has(.d-icon-plus)");
    assert.true(this.onChange.calledTwice);
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

    this.configuration = {};
    this.node = {
      clientId: "trigger-1",
      type: "trigger:form",
      webhookId: "a1b2c3d4-e5f6-7890-abcd-ef0123456789",
    };
    this.nodeType = "trigger:form";
    this.schema = {
      url_preview: {
        type: "custom",
        ui: {
          control: "url_preview",
        },
      },
    };

    await renderEngine(this);

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

    this.configuration = { path: "my-hook" };
    this.node = { clientId: "webhook-1", type: "trigger:webhook" };
    this.nodeType = "trigger:webhook";
    this.schema = {
      path: {
        type: "string",
      },
      url_preview: {
        type: "custom",
        ui: {
          control: "url_preview",
        },
      },
    };

    await renderEngine(this);

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
    this.configuration = { icon: "gear" };
    this.nodeType = "trigger:topic_admin_button";
    this.schema = {
      icon: {
        type: "icon",
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    assert.dom(".form-kit__control-icon").exists();
    assert.dom(".form-kit__control-icon").hasAttribute("data-value", "gear");

    await click(".form-kit__control-icon .d-icon-grid-picker-trigger");
    await waitFor(".d-icon-grid-picker__icon");
    await click('[data-icon-id="bolt"]');

    assert.dom(".form-kit__control-icon").hasAttribute("data-value", "bolt");

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.strictEqual(formApi.get("icon"), "=bolt");
    assert.dom(".workflows-variable-input").exists();
  });

  test("shows expected value hints in dynamic mode", async function (assert) {
    this.configuration = { channel_id: "2" };
    this.nodeType = "action:send_chat_message";
    this.schema = {
      channel_id: {
        type: "integer",
        ui: {
          dynamic_value: "chat_channel_id",
        },
      },
    };

    await renderEngine(this, { withFormApi: true });

    assert.dom(".workflows-property-engine__dynamic-hint").doesNotExist();

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert
      .dom(".workflows-property-engine__dynamic-hint")
      .hasText("Must resolve to a chat channel ID.");
  });

  test("select fields render with correct initial value", async function (assert) {
    this.configuration = { combinator: "or" };
    this.nodeType = "condition:if";
    this.schema = {
      combinator: {
        type: "options",
        options: ["and", "or"],
        default: "and",
        no_data_expression: true,
      },
    };

    await renderEngine(this);

    assert.dom("select").hasValue("or");
  });

  test("updates badge reason visibility when the selected badge changes", async function (assert) {
    this.configuration = { operation: "grant", badge_id: 1 };
    this.nodeType = "action:badge";
    this.nodeTypes = [
      {
        identifier: "action:badge",
        metadata: {
          badges: [
            { id: 1, name: "Community badge", hide_reason: false },
            { id: 2, name: "Anniversary", hide_reason: true },
          ],
        },
      },
    ];
    this.schema = {
      badge_id: {
        type: "integer",
        type_options: { load_options_method: "badges" },
        ui: { control: "combo_box" },
        control_options: { value_property: "id", name_property: "name" },
      },
      reason: {
        type: "string",
        display_options: {
          show: { operation: ["grant"] },
          hide: {
            badge_id: [
              {
                condition: {
                  metadata_flag: { collection: "badges", flag: "hide_reason" },
                },
              },
            ],
          },
        },
      },
    };

    await renderEngine(this);
    assert.dom('input[name="reason"]').exists("a badge can show its reason");

    const badgeChooser = selectKit(".combo-box");
    await badgeChooser.expand();
    await badgeChooser.selectRowByValue(2);
    assert
      .dom('input[name="reason"]')
      .doesNotExist("the selected badge can never display its reason");

    await badgeChooser.expand();
    await badgeChooser.selectRowByValue(1);
    assert
      .dom('input[name="reason"]')
      .exists("switching back restores the reason field");
  });

  test("renders combo boxes from metadata and applies option patches", async function (assert) {
    this.configuration = {
      agent_force_default_llm: true,
      agent_id: 2,
      agent_name: "",
      llm_model_id: 99,
    };
    this.nodeType = "action:ai_agent";
    this.nodeTypes = [
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
    ];
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const selector = selectKit(".combo-box");
    assert.strictEqual(selector.header().value(), "2");
    assert.strictEqual(selector.header().label(), "Helper Bot");

    await selector.expand();
    await selector.selectRowByValue("1");

    assert.strictEqual(String(formApi.get("agent_id")), "1");
    assert.false(formApi.get("agent_force_default_llm"));
    assert.strictEqual(formApi.get("agent_name"), "Support Bot");
    assert.strictEqual(formApi.get("llm_model_id"), null);
  });

  test("renders combo box actions with the selected field value as a route model", async function (assert) {
    const router = this.owner.lookup("service:router");
    const transitionTo = sinon.stub(router, "transitionTo");

    this.configuration = {
      workflow_id: null,
    };
    this.nodeType = "action:workflow_call";
    this.nodeTypes = [
      {
        identifier: "action:workflow_call",
        metadata: {
          callable_workflows: [{ id: 8, name: "Child workflow" }],
        },
      },
    ];
    this.schema = {
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
    };

    await renderEngine(this);

    assert
      .dom(".workflows-property-engine__select-with-action > .btn")
      .doesNotExist();

    const selector = selectKit(".combo-box");
    await selector.expand();
    await selector.selectRowByValue("8");

    assert
      .dom(".workflows-property-engine__select-with-action > .btn")
      .hasAttribute("title", "Open workflow")
      .hasAria("label", "Open workflow");

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

    this.configuration = {
      agent_force_default_llm: true,
      agent_id: null,
      agent_name: "",
      agent_resolved_llm_name: "",
      llm_model_id: 99,
    };
    this.node = {
      clientId: "node-1",
      type: "action:ai_agent",
      typeVersion: "1.0",
    };
    this.nodeType = "action:ai_agent";
    this.nodeTypes = [
      {
        identifier: "action:ai_agent",
        name: "action:ai_agent",
        version: "1.0",
      },
    ];
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const selector = selectKit(".combo-box");
    await selector.expand();
    await waitFor(".combo-box .select-kit-row[data-value='1']");
    await selector.selectRowByValue("1");

    assert.strictEqual(String(formApi.get("agent_id")), "1");
    assert.false(formApi.get("agent_force_default_llm"));
    assert.strictEqual(formApi.get("agent_name"), "Support Bot");
    assert.strictEqual(formApi.get("agent_resolved_llm_name"), "Default LLM");
    assert.strictEqual(formApi.get("llm_model_id"), null);
    assert.true(requests.length >= 1);
    assert.strictEqual(requests[0].methodName, "agents");
  });

  test("renders combo box dynamic none labels from configuration", async function (assert) {
    this.configuration = {
      agent_resolved_llm_name: "Workflow LLM",
      llm_model_id: null,
    };
    this.nodeType = "action:ai_agent";
    this.nodeTypes = [
      {
        identifier: "action:ai_agent",
        metadata: {
          llm_models: [{ id: 1, name: "Override LLM" }],
        },
      },
    ];
    this.schema = {
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
    };

    await renderEngine(this);

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

    this.configuration = {
      operation: "get",
      topic_id: "21",
      custom_field_names: [],
    };
    this.node = {
      clientId: "node-1",
      type: "action:topic",
      typeVersion: "1.0",
    };
    this.nodeType = "action:topic";
    this.nodeTypes = [
      {
        identifier: "action:topic",
        name: "action:topic",
        version: "1.0",
        metadata: {
          topic_custom_fields: [{ id: "system", name: "system" }],
        },
      },
    ];
    this.schema = {
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
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const selector = selectKit(".multi-select");
    await selector.expand();
    await waitFor(".multi-select .select-kit-row[data-value='foo']");
    await selector.selectRowByValue("foo");

    assert.deepEqual(formApi.get("custom_field_names"), ["foo"]);
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
    this.configuration = { upload_ids: [] };
    this.nodeType = "action:ai_agent";
    this.schema = {
      upload_ids: {
        type: "array",
        required: false,
        ui: {
          control: "multi_input",
          expression: true,
        },
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const selector = selectKit(".multi-select");

    await selector.expand();
    await selector.fillInFilter("12");
    await selector.selectRowByValue("12");
    await selector.fillInFilter("34");
    await selector.selectRowByValue("34");

    assert.deepEqual(
      formApi.get("upload_ids"),
      ["12", "34"],
      "stores entered ids"
    );

    await click(
      '.workflows-property-engine__mode-control input[value="dynamic"]'
    );

    assert.strictEqual(
      formApi.get("upload_ids"),
      '={{ ["12","34"] }}',
      "converts the fixed list into a dynamic expression"
    );

    await click(
      '.workflows-property-engine__mode-control input[value="plain"]'
    );

    assert.deepEqual(
      formApi.get("upload_ids"),
      ["12", "34"],
      "converts the dynamic expression back into a fixed list"
    );
  });

  test("boolean assignment values convert between fixed and dynamic", async function (assert) {
    this.configuration = {
      fields: {
        assignments: [{ name: "active", type: "boolean", value: false }],
      },
    };
    this.nodeType = "action:workflow_call";
    this.schema = {
      fields: {
        type: "assignment_collection",
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const row = ".workflows-property-engine__collection-row";

    assert
      .dom(`${row} .form-kit__control-toggle`)
      .exists("starts as a plain toggle");
    assert
      .dom(`${row} .workflows-property-engine__mode-control`)
      .exists("offers a dynamic mode for boolean assignments");

    await click(
      `${row} .workflows-property-engine__mode-control input[value="dynamic"]`
    );

    assert
      .dom(`${row} .workflows-variable-input`)
      .exists("swaps the toggle for an expression input");
    assert.strictEqual(
      formApi.get("fields.assignments.0.value"),
      "=false",
      "seeds the expression with the previous fixed value"
    );

    await click(
      `${row} .workflows-property-engine__mode-control input[value="plain"]`
    );

    assert.false(
      formApi.get("fields.assignments.0.value"),
      "converts the expression back into a fixed boolean, not the string 'false'"
    );
  });

  test("boolean assignment values saved as expressions render in dynamic mode", async function (assert) {
    this.configuration = {
      fields: {
        assignments: [
          { name: "active", type: "boolean", value: "={{ $json.enabled }}" },
        ],
      },
    };
    this.nodeType = "action:workflow_call";
    this.schema = {
      fields: {
        type: "assignment_collection",
      },
    };

    await renderEngine(this);

    assert.dom(".form-kit__control-toggle").doesNotExist();
    assert.dom(".workflows-variable-input").includesText("enabled");
  });

  test("switching an assignment to boolean keeps an expression it already holds", async function (assert) {
    this.configuration = {
      fields: {
        assignments: [
          { name: "active", type: "string", value: "={{ $json.enabled }}" },
        ],
      },
    };
    this.nodeType = "action:workflow_call";
    this.schema = {
      fields: {
        type: "assignment_collection",
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    await select(
      ".workflows-property-engine__collection-row select",
      "boolean"
    );

    assert.strictEqual(
      formApi.get("fields.assignments.0.value"),
      "={{ $json.enabled }}",
      "keeps the expression when the type changes"
    );
    assert
      .dom(".form-kit__control-toggle")
      .doesNotExist("does not fall back to a toggle over an expression");
    assert.dom(".workflows-variable-input").includesText("enabled");
  });

  test("resets plain assignment values that don't fit the new type", async function (assert) {
    this.configuration = {
      fields: {
        assignments: [{ name: "active", type: "string", value: "hello" }],
      },
    };
    this.nodeType = "action:workflow_call";
    this.schema = {
      fields: {
        type: "assignment_collection",
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    const typeSelect = ".workflows-property-engine__collection-row select";

    await select(typeSelect, "boolean");

    assert.false(
      formApi.get("fields.assignments.0.value"),
      "a string is not carried into the toggle as truthy"
    );

    await select(typeSelect, "array");

    assert.strictEqual(
      formApi.get("fields.assignments.0.value"),
      "",
      "a boolean is not carried into the JSON editor"
    );
  });

  // Rows are keyed by index, so the survivor reuses the deleted row's component.
  test("removing a boolean assignment row keeps the survivor's expression", async function (assert) {
    this.configuration = {
      fields: {
        assignments: [
          { name: "flagged", type: "boolean", value: false },
          { name: "active", type: "boolean", value: "={{ $json.enabled }}" },
        ],
      },
    };
    this.nodeType = "action:workflow_call";
    this.schema = {
      fields: {
        type: "assignment_collection",
      },
    };

    const formApi = await renderEngine(this, { withFormApi: true });

    await click(findAll(".workflows-property-engine__collection-delete")[0]);

    assert.strictEqual(
      formApi.get("fields.assignments.0.value"),
      "={{ $json.enabled }}",
      "leaves the surviving expression untouched"
    );
    assert
      .dom(".form-kit__control-toggle")
      .doesNotExist("does not offer a toggle that would overwrite it");
    assert.dom(".workflows-variable-input").includesText("enabled");
  });
});
