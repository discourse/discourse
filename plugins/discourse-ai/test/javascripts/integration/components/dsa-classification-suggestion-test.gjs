import { click, render, waitFor, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import DsaModeration from "discourse/components/dsa-moderation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  controllerRateLimit,
  response,
} from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";

const endpoint = "/discourse-ai/ai-moderation/dsa-classifications/42/suggest";
const rule = "[data-name='community_rule']";
const category = "[data-name='category']";
const hint = ".form-kit__container-help-text";

function renderForm(
  communityRules = [
    { id: "spam", ground: "No spam" },
    { id: "abuse", ground: "Be civil" },
  ]
) {
  const options = {
    community_rules: communityRules,
    categories: [
      { id: "other", name: "Other" },
      { id: "fraud", name: "Fraud" },
    ],
    default_category: "other",
  };
  return render(
    <template>
      <DsaModeration
        @hasActionDetails={{false}}
        @options={{options}}
        @reviewableId={{42}}
        as |flow|
      >
        <flow.Body />
      </DsaModeration>
    </template>
  );
}

module(
  "Integration | Component | DSA classification suggestions",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.discourse_ai_enabled = true;
      this.siteSettings.ai_dsa_classification_decision_model = 1;
    });

    test("leaves manual classification available when no AI model is configured", async function (assert) {
      this.siteSettings.ai_dsa_classification_decision_model = "";
      await renderForm();
      assert
        .dom(".dsa-classification-select")
        .isEnabled("allows choosing a rule");
      assert
        .dom(`${category} select`)
        .hasValue("other", "keeps the default category");
      assert.dom(hint).doesNotExist("shows no AI guidance");
    });

    test("shows loading indicators and disables the fields until the request finishes", async function (assert) {
      let request;
      pretender.post(
        endpoint,
        (xhr) => {
          request = xhr;
          return response({ category: "fraud" });
        },
        true
      );
      const rendered = renderForm();
      try {
        await waitFor(`${category} .d-icon-spinner`);
        for (const field of [rule, category]) {
          assert.dom(`${field} .d-icon-spinner`).exists("shows the spinner");
          assert
            .dom(`${field} ${hint}`)
            .hasText("AI is generating", "explains the pending request");
        }
        assert.dom(".dsa-classification-select").isDisabled("locks the rule");
        assert.dom(`${category} select`).isDisabled("locks the category");
      } finally {
        await waitUntil(() => request);
        pretender.resolve(request);
        await rendered;
      }
      assert.dom(".dsa-classification-select").isEnabled("unlocks the rule");
      assert.dom(`${category} select`).isEnabled("unlocks the category");
    });

    test("labels only the category when AI suggests a category but no rule", async function (assert) {
      pretender.post(endpoint, () => response({ category: "fraud" }));
      await renderForm();
      assert
        .dom(`${category} select`)
        .hasValue("fraud", "prefills the category");
      assert
        .dom(`${category} ${hint}`)
        .hasText("Suggested by AI", "labels the suggestion");
      assert.dom(`${rule} ${hint}`).doesNotExist("leaves the rule unlabeled");
    });

    test("clears each inline error when its field changes", async function (assert) {
      pretender.post(endpoint, () => controllerRateLimit());
      await renderForm();
      assert
        .dom(`${rule} ${hint}`)
        .hasText(
          "AI request limit reached. Choose a rule manually.",
          "explains how to choose a rule"
        );
      assert
        .dom(`${category} ${hint}`)
        .hasText(
          "AI request limit reached. Review the selected category.",
          "explains how to review the category"
        );
      await click(".dsa-classification-select");
      await click(".dsa-classification-option[data-value='spam']");
      assert.dom(`${rule} ${hint}`).doesNotExist("clears the rule error");
      assert.dom(`${category} ${hint}`).exists("keeps the category error");
      await formKit().field("category").select("fraud");
      assert
        .dom(`${category} ${hint}`)
        .doesNotExist("clears the category error");
    });

    test("preserves the sole rule and shows manual guidance only for Category", async function (assert) {
      pretender.post(endpoint, () => response({ community_rule: "spam" }));
      await renderForm([{ id: "spam", ground: "No spam" }]);
      assert
        .dom(".dsa-classification-select")
        .hasText("No spam", "keeps the site's rule");
      assert
        .dom(`${rule} ${hint}`)
        .doesNotExist("shows no guidance for the sole rule");
      assert
        .dom(`${category} ${hint}`)
        .includesText("Review the selected category.", "guides the moderator");
    });
  }
);
