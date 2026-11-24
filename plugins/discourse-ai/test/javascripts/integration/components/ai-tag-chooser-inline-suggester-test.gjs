import { hash } from "@ember/helper";
import { trackedObject } from "@ember/reactive/collections";
import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withSilencedDeprecationsAsync } from "discourse/lib/deprecated";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { optionWithText } from "discourse/tests/helpers/d-select-hosts";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import { i18n } from "discourse-i18n";
import categorySuggester from "discourse/plugins/discourse-ai/discourse/initializers/ai-category-chooser-inline-suggester";
import tagSuggester from "discourse/plugins/discourse-ai/discourse/initializers/ai-tag-chooser-inline-suggester";

module("Integration | Component | AI tag suggester", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.discourse_ai_enabled = true;
    this.siteSettings.ai_helper_enabled = true;
    this.siteSettings.ai_embeddings_enabled = true;
    this.siteSettings.ai_helper_enabled_features = "suggestions";
    this.currentUser.can_use_assistant = true;
    tagSuggester.initialize(this.owner);
  });

  test("a pending suggestion request is captioned in the loading state", async function (assert) {
    let resolveSuggestions;
    pretender.post("/discourse-ai/ai-helper/suggest_tags", async () => {
      await new Promise((resolve) => (resolveSuggestions = resolve));
      return response({ assistant: [] });
    });
    const composer = {
      reply: "A reply long enough for the assistant to suggest some tags.",
      tags: [],
    };

    await render(
      <template>
        <DSelectTag
          @identifier="composer-tags"
          @instanceContext={{hash composer=composer}}
          @multiple={{true}}
        />
      </template>
    );
    await click("[role='combobox']");
    const suggesting = click(
      optionWithText(i18n("discourse_ai.ai_helper.suggest"))
    );
    await waitFor(".d-select__loading-status");

    assert
      .dom(".d-select__loading-status")
      .hasText(i18n("discourse_ai.ai_helper.context_menu.loading"));

    resolveSuggestions();
    await suggesting;
  });

  test("the suggest row draws its icon once", async function (assert) {
    const composer = {
      reply: "A reply long enough for the assistant to suggest some tags.",
      tags: [],
    };

    await render(
      <template>
        <DSelectTag
          @identifier="composer-tags"
          @instanceContext={{hash composer=composer}}
          @multiple={{true}}
        />
      </template>
    );
    await click("[role='combobox']");

    assert
      .dom(
        "[role='option'][data-value='ai-tag-suggest'] .d-icon-discourse-sparkles"
      )
      .exists({ count: 1 });
  });
});

module("Integration | Component | AI category suggester", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_new_select_controls = true;
    this.siteSettings.discourse_ai_enabled = true;
    this.siteSettings.ai_helper_enabled = true;
    this.siteSettings.ai_embeddings_enabled = true;
    this.siteSettings.ai_helper_enabled_features = "suggestions";
    this.currentUser.can_use_assistant = true;
    categorySuggester.initialize(this.owner);
  });

  test("the suggest row draws its icon once", async function (assert) {
    const current = Category.findById(2);
    Site.current().set("categories", [current]);
    const composer = trackedObject({
      title: "A title for category suggestions",
      reply: "A reply long enough for the assistant to suggest a category.",
      categoryId: current.id,
    });

    // The plugin's legacy category content callback still runs through the bridge.
    await withSilencedDeprecationsAsync(
      "discourse.select-kit.modify-select-kit-content",
      async () => {
        await render(
          <template>
            <DSelectCategory
              @emit="ids"
              @identifier="composer-category"
              @instanceContext={{hash composer=composer}}
              @permission="create"
              @value={{composer.categoryId}}
              @variant="button"
            />
          </template>
        );
        await dSelect().open();
      }
    );

    assert
      .dom(
        "[role='option'][data-value='ai-category-suggest'] .d-icon-discourse-sparkles"
      )
      .exists({ count: 1 });
  });

  test("the AI category suggester cannot select a read-only category", async function (assert) {
    const current = Category.findById(2);
    const readOnly = Category.create({
      id: 9900,
      name: "Read only",
      slug: "read-only",
      permission: null,
    });
    Site.current().set("categories", [current, readOnly]);
    const composer = trackedObject({
      title: "A title for category suggestions",
      reply: "A reply long enough for the assistant to suggest a category.",
      categoryId: current.id,
    });
    const onChange = sinon.spy((value) => (composer.categoryId = value));
    const requests = [];
    pretender.post("/discourse-ai/ai-helper/suggest_category", (request) => {
      requests.push(new URLSearchParams(request.requestBody));
      return response({
        assistant: [{ id: String(readOnly.id), name: readOnly.name }],
      });
    });
    // The plugin's legacy category content callback still runs through the bridge.
    await withSilencedDeprecationsAsync(
      "discourse.select-kit.modify-select-kit-content",
      async () => {
        await render(
          <template>
            <DSelectCategory
              @emit="ids"
              @identifier="composer-category"
              @instanceContext={{hash composer=composer}}
              @onChange={{onChange}}
              @permission="create"
              @readOnlyCategories={{readOnly.id}}
              @value={{composer.categoryId}}
              @variant="button"
            />
          </template>
        );
        await dSelect().open();
      }
    );
    assert
      .dom('[role="option"][data-value="9900"]')
      .hasAttribute(
        "aria-disabled",
        "true",
        "the recipe declares this suggested category read-only"
      );
    assert
      .dom('[role="option"][data-value="ai-category-suggest"]')
      .exists("the actual category suggester action is available");

    await click('[role="option"][data-value="ai-category-suggest"]');

    assert.strictEqual(
      requests.length,
      1,
      "the real suggestion request completed"
    );
    assert.true(
      requests[0].get("text").includes(composer.title),
      "the request uses the chooser's composer context"
    );
    assert.strictEqual(
      onChange.callCount,
      0,
      "the suggestion's bare record cannot bypass the recipe's disabled item"
    );
    assert.strictEqual(
      composer.categoryId,
      current.id,
      "the composer keeps its original category"
    );
    assert
      .dom(".d-select__value")
      .includesText(
        current.name,
        "the closed trigger keeps the held category name"
      );
    assert
      .dom('[role="listbox"]')
      .doesNotExist("the suggester finishes with the chooser closed");
    assert
      .dom(".d-select__loading-status")
      .doesNotExist("refusing the suggestion still finishes the update");
  });
});
