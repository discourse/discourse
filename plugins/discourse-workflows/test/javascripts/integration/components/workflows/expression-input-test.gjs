import {
  click,
  find,
  render,
  settled,
  triggerKeyEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import ExpressionInput from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/expression-input";
import WorkflowEditorSession from "discourse/plugins/discourse-workflows/admin/lib/workflows/editor-session";

const PICKER = ".workflows-reference-picker";

/** A session whose trigger outputs a post, so `$json.post.*` references resolve. */
function postSession() {
  const trigger = {
    clientId: "trigger",
    name: "Trigger",
    type: "trigger:manual",
  };
  const action = { clientId: "action", name: "Action", type: "action:topic" };
  const session = new WorkflowEditorSession();
  session.setEditingContext(
    action,
    [trigger, action],
    [{ sourceClientId: "trigger", targetClientId: "action" }]
  );
  session.outputSchemas = {
    trigger: [
      {
        type: "object",
        properties: {
          post: {
            type: "object",
            properties: {
              raw: { type: "string" },
              title: { type: "string" },
            },
          },
        },
      },
    ],
  };
  return session;
}

/** Renders a titled field holding `$json.post.raw`, the way a form field does. */
async function renderField(context) {
  const session = postSession();
  const field = {
    value: "={{ $json.post.raw }}",
    set: sinon.spy(),
    labelId: "topic-label",
    showTitle: true,
  };
  await render(
    <template>
      <span id="topic-label">Topic ID</span>
      <ExpressionInput @field={{field}} @session={{session}} />
      <DMenus />
    </template>
  );
  await waitFor(".cm-wf-reference-pill.--value");
  context.field = field;
}

/** Opens the picker from the field's pill, as Enter on a selected pill does. */
async function openPicker(context) {
  await renderField(context);
  await click(".cm-wf-reference-pill");
  await triggerKeyEvent(".cm-content", "keydown", "Enter");
  await waitFor(PICKER);
}

module(
  "Integration | Component | Workflows | expression input",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response(200, { variables: [] })
      );
    });

    test("refreshes the $json scope when output schemas load", async function (assert) {
      const trigger = {
        clientId: "trigger",
        name: "Trigger",
        type: "trigger:manual",
      };
      const action = {
        clientId: "action",
        name: "Action",
        type: "action:topic",
      };
      const session = new WorkflowEditorSession();
      session.setEditingContext(
        action,
        [trigger, action],
        [{ sourceClientId: "trigger", targetClientId: "action" }]
      );
      const field = { value: "={{ $json.post.raw }}", set() {} };

      await render(
        <template>
          <ExpressionInput @field={{field}} @session={{session}} />
        </template>
      );
      await waitFor(".cm-wf-reference-pill");

      assert.dom(".cm-wf-reference-pill").hasClass("--invalid");

      session.outputSchemas = {
        trigger: [
          {
            type: "object",
            properties: {
              post: { type: "object", properties: { raw: { type: "string" } } },
            },
          },
        ],
      };
      await settled();

      assert.dom(".cm-wf-reference-pill").hasClass("--value");
    });
  }
);

module(
  "Integration | Component | Workflows | expression input | reference picker",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response(200, { variables: [] })
      );
      pretender.post(
        "/admin/plugins/discourse-workflows/expressions/evaluate.json",
        () => response(200, { segments: [] })
      );
    });

    test("keeps today's picker without new select controls", async function (assert) {
      await openPicker(this);

      assert
        .dom(`${PICKER}__filter`)
        .hasAria(
          "label",
          i18n("discourse_workflows.reference_pill.properties"),
          "the search is named by what it lists, not by its placeholder"
        );
      assert.dom(`${PICKER} .d-select.--list`).doesNotExist();
    });

    test("is named by its field's label, and says Enter opens a reference's properties", async function (assert) {
      await renderField(this);

      assert.dom(".cm-content").hasAria("labelledby", "topic-label");
      const hint = document.getElementById(
        find(".cm-content").getAttribute("aria-describedby")
      );
      assert
        .dom(hint)
        .hasText(i18n("discourse_workflows.reference_pill.editor_hint"));
    });

    module("with new select controls", function (flagHooks) {
      flagHooks.beforeEach(function () {
        this.siteSettings.enable_new_select_controls = true;
      });

      test("lists the properties from the current one, and a pick replaces it", async function (assert) {
        await openPicker(this);

        assert.dom(`${PICKER} .d-select.--list`).exists();
        assert.deepEqual(
          [...document.querySelectorAll(`${PICKER} [role='option']`)].map(
            (row) => row.dataset.name
          ),
          ["raw", "title"]
        );
        assert
          .dom(`${PICKER} .d-select__input`)
          .isFocused()
          .hasAria(
            "label",
            i18n("discourse_workflows.reference_pill.properties"),
            "the search is named by what it lists, not by its placeholder"
          );
        assert
          .dom(`${PICKER} [role='option'].--active`)
          .hasAttribute("data-name", "raw", "the current property is active");

        await click(`${PICKER} [role='option'][data-name='title']`);

        assert.dom(PICKER).doesNotExist("the pick closes the picker");
        assert.true(this.field.set.calledWith("={{ $json.post.title }}"));
      });

      test("picking the current property again closes the picker on the pill", async function (assert) {
        await openPicker(this);
        await triggerKeyEvent(`${PICKER} .d-select__input`, "keydown", "Enter");

        assert.dom(PICKER).doesNotExist();
        assert.dom(".cm-content").isFocused();
        assert.dom(".cm-wf-reference-pill").hasClass("--selected");
        assert.deepEqual(
          this.field.set.args.filter(([value]) => value !== this.field.value),
          [],
          "the reference is unchanged"
        );
      });

      test("Escape closes the picker and returns to the selected pill", async function (assert) {
        await openPicker(this);
        await triggerKeyEvent(
          `${PICKER} .d-select__input`,
          "keydown",
          "Escape"
        );

        assert.dom(PICKER).doesNotExist();
        assert.dom(".cm-content").isFocused();
        assert.dom(".cm-wf-reference-pill").hasClass("--selected");
      });
    });
  }
);
