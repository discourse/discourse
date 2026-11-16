import { render, waitFor, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import VariableInput from "discourse/plugins/discourse-workflows/admin/components/workflows/variable/input";
import { buildHoverTooltip } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-extensions/hover-tooltip";
import { buildValidation } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-extensions/validation";
import { expressionUtils } from "discourse/plugins/discourse-workflows/admin/lib/workflows/expression-language/index";

function diagnosticsOf(cmLint, state) {
  const found = [];
  cmLint.forEachDiagnostic(state, ({ severity, message }, from, to) =>
    found.push({ severity, message, from, to })
  );
  return found;
}

module(
  "Integration | Component | Workflows | expression validation",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      pretender.get("/admin/plugins/discourse-workflows/variables.json", () =>
        response(200, { variables: [] })
      );
    });

    test("reports an unclosed expression until it is closed", async function (assert) {
      const value = "Hi {{ $json.title";
      let cmLint;
      let editorView;
      const extensions = (cmParams) => {
        cmLint = cmParams.cmLint;
        return [
          expressionUtils(cmParams).expressionLanguage(),
          buildValidation(cmParams),
        ];
      };
      const onSetup = (view) => (editorView = view);

      await render(
        <template>
          <VariableInput
            @extensions={{extensions}}
            @onSetup={{onSetup}}
            @value={{value}}
          />
        </template>
      );
      await waitFor(".cm-wf-error");

      assert.deepEqual(
        diagnosticsOf(cmLint, editorView.state),
        [
          {
            severity: "error",
            message: i18n(
              "discourse_workflows.expression_language.unclosed_expression"
            ),
            from: 3,
            to: value.length,
          },
        ],
        "the open expression is an error running to the end of the input"
      );

      editorView.dispatch({
        changes: { from: value.length, insert: " }}" },
      });
      await waitUntil(() => !this.element.querySelector(".cm-wf-error"));

      assert.deepEqual(
        diagnosticsOf(cmLint, editorView.state),
        [],
        "closing the expression clears the error"
      );
    });

    test("shows the error in the same hover tooltip as the docs", async function (assert) {
      const value = "Hi {{ 1 + $json";
      let editorView;
      const extensions = (cmParams) => {
        const params = { ...cmParams, utils: expressionUtils(cmParams) };
        return [
          params.utils.expressionLanguage(),
          buildValidation(params),
          buildHoverTooltip(params, { scope: {} }),
        ];
      };
      const onSetup = (view) => (editorView = view);

      await render(
        <template>
          <VariableInput
            @extensions={{extensions}}
            @onSetup={{onSetup}}
            @value={{value}}
          />
        </template>
      );
      await waitFor(".cm-wf-error");

      const pos = value.indexOf("$json") + 2;
      const target = editorView.domAtPos(pos).node.parentElement;
      // Hover is resolved from the pointer position, so the text must be on screen.
      target.scrollIntoView({ block: "center" });
      const { left, top, bottom } = editorView.coordsAtPos(pos);
      target.dispatchEvent(
        new MouseEvent("mousemove", {
          bubbles: true,
          clientX: left + 1,
          clientY: (top + bottom) / 2,
        })
      );
      const sectionsShown = () =>
        document.querySelectorAll(".cm-tooltip-hover .cm-tooltip-section");
      await waitUntil(() => sectionsShown().length === 2, { timeout: 3000 });

      const sections = [...sectionsShown()];
      assert
        .dom(sections[0])
        .hasText(
          i18n("discourse_workflows.expression_language.unclosed_expression")
        );
      assert.dom(".cm-wf-hover-tooltip__name", sections[1]).hasText("$json");
    });
  }
);
