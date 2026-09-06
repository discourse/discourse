import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";
import RagDocumentSourcesModal from "discourse/plugins/discourse-ai/discourse/components/modal/rag-document-sources-modal";

module(
  "Integration | Component | Modal | RagDocumentSourcesModal",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.savedData = null;
      this.model = {
        sources: [],
        onSave: (data) => (this.savedData = data),
      };
      this.closeModal = () => {};
    });

    test("accepts one URL per line with a shared refresh interval", async function (assert) {
      await render(
        <template>
          <RagDocumentSourcesModal
            @model={{this.model}}
            @closeModal={{this.closeModal}}
            @inline={{true}}
          />
        </template>
      );

      assert
        .dom('[data-name="refresh_interval_hours"] input')
        .hasValue("24", "the refresh interval defaults to 24 hours");

      await fillIn(
        '[data-name="urls"] textarea',
        "https://example.com/one\n\nhttps://example.com/two\nhttps://example.com/one"
      );
      await fillIn('[data-name="refresh_interval_hours"] input', "48");
      await formKit().submit();

      assert.deepEqual(
        this.savedData,
        {
          urls: ["https://example.com/one", "https://example.com/two"],
          refreshIntervalHours: 48,
        },
        "blank lines and duplicate URLs are removed"
      );
    });

    test("rejects more than 100 URLs", async function (assert) {
      await render(
        <template>
          <RagDocumentSourcesModal
            @model={{this.model}}
            @closeModal={{this.closeModal}}
            @inline={{true}}
          />
        </template>
      );

      const urls = Array.from(
        { length: 101 },
        (_value, index) => `https://example.com/${index}`
      ).join("\n");
      await fillIn('[data-name="urls"] textarea', urls);
      await formKit().submit();

      assert
        .form()
        .field("urls")
        .hasError(i18n("discourse_ai.rag.sources.too_many", { count: 100 }));
      assert.strictEqual(
        this.savedData,
        null,
        "the invalid source list is not saved"
      );
    });
  }
);
