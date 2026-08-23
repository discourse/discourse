import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import RagDocumentSources from "discourse/plugins/discourse-ai/discourse/components/rag-document-sources";

class ModalStub extends Service {
  show(_component, options) {
    this.model = options.model;
  }
}

module("Integration | Component | RagDocumentSources", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:modal");
    this.owner.register("service:modal", ModalStub);
    this.sources = [
      { id: 1, url: "https://example.com/one", refresh_interval_hours: 24 },
      { id: 2, url: "https://example.com/two", refresh_interval_hours: 24 },
      { id: 3, url: "https://example.com/three", refresh_interval_hours: 24 },
      { id: 4, url: "https://example.com/four", refresh_interval_hours: 24 },
    ];
    this.updatedSources = null;
    this.form = {
      set: (_name, sources) => (this.updatedSources = sources),
    };
  });

  test("shows a short URL summary on existing agents", async function (assert) {
    await render(
      <template>
        <RagDocumentSources
          @form={{this.form}}
          @sources={{this.sources}}
          @isNew={{false}}
        />
      </template>
    );

    assert
      .dom(".rag-document-sources__count")
      .hasText("4 URL sources", "the total URL count is shown");
    assert
      .dom(".rag-document-sources__url")
      .exists({ count: 3 }, "only three URLs are shown");
    assert
      .dom(".rag-document-sources__remaining")
      .hasText("And 1 more URL", "the remaining count is summarized");
    assert
      .dom(".rag-document-sources")
      .doesNotIncludeText("Indexed", "indexing details are not shown");
  });

  test("does not show the URL summary on new agents", async function (assert) {
    await render(
      <template>
        <RagDocumentSources
          @form={{this.form}}
          @sources={{this.sources}}
          @isNew={{true}}
        />
      </template>
    );

    assert.dom(".rag-document-sources__count").doesNotExist();
    assert.dom(".rag-document-sources__url").doesNotExist();
    assert.dom(".rag-document-sources__edit").exists("the add button remains");
  });

  test("updates all sources with the modal refresh interval", async function (assert) {
    await render(
      <template>
        <RagDocumentSources
          @form={{this.form}}
          @sources={{this.sources}}
          @isNew={{false}}
        />
      </template>
    );

    await click(".rag-document-sources__edit");
    this.owner.lookup("service:modal").model.onSave({
      urls: ["https://example.com/two", "https://example.com/new"],
      refreshIntervalHours: 48,
    });

    assert.deepEqual(
      this.updatedSources,
      [
        {
          id: 2,
          url: "https://example.com/two",
          refresh_interval_hours: 48,
        },
        {
          url: "https://example.com/new",
          refresh_interval_hours: 48,
        },
      ],
      "existing IDs are preserved and one refresh interval is applied"
    );
  });
});
