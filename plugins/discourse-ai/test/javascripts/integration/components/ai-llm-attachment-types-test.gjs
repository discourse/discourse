import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";
import AiLlmAttachmentTypes from "discourse/plugins/discourse-ai/discourse/components/ai-llm-attachment-types";

function optionNames() {
  return [...document.querySelectorAll("[role='option']")].map((option) =>
    option.textContent.trim()
  );
}

module(
  "Integration | Component | ai-llm-attachment-types with the new select controls",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("offers the common types and the held ones, in order", async function (assert) {
      const value = ["zip", "pdf"];
      const noop = () => {};

      await render(
        <template>
          <AiLlmAttachmentTypes
            @id="attachment-types"
            @onChange={{noop}}
            @value={{value}}
          />
        </template>
      );

      assert
        .dom("#attachment-types")
        .hasAttribute("role", "combobox", "takes the field's id");
      assert.dom(".d-select__chip[data-value='zip']").exists();

      await dSelect().open();
      assert.deepEqual(optionNames(), [
        "csv",
        "doc",
        "docx",
        "html",
        "md",
        "ods",
        "odt",
        "pdf",
        "rtf",
        "txt",
        "xls",
        "xlsx",
        "zip",
      ]);
    });

    test("adds a typed type in lowercase, trimmed", async function (assert) {
      const changes = [];
      const onChange = (types) => changes.push([...types]);
      const value = ["pdf"];

      await render(
        <template>
          <AiLlmAttachmentTypes @onChange={{onChange}} @value={{value}} />
        </template>
      );

      await dSelect().search(" XLSB ");
      await dSelect().select("xlsb");

      assert.deepEqual(changes, [["pdf", "xlsb"]]);
    });

    test("asks for types while it holds none", async function (assert) {
      const noop = () => {};

      await render(
        <template><AiLlmAttachmentTypes @onChange={{noop}} /></template>
      );

      assert
        .dom("[role='combobox']")
        .hasAttribute(
          "placeholder",
          i18n("discourse_ai.llms.attachment_types_placeholder")
        );
    });
  }
);
