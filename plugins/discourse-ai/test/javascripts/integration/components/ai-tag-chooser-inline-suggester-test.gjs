import { hash } from "@ember/helper";
import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { optionWithText } from "discourse/tests/helpers/d-select-hosts";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import { i18n } from "discourse-i18n";
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
});
