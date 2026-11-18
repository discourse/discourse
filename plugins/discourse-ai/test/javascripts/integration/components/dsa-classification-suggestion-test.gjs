import { click, render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import DsaModeration from "discourse/components/dsa-moderation";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  controllerRateLimit,
  response,
} from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";

const endpoint = "/discourse-ai/ai-moderation/dsa-classifications/42/suggest";
const suggest = ".dsa-classification-footer button";
const rule = "[data-name='community_rule']";
const category = "[data-name='category']";
const hint = ".form-kit__container-help-text";

function renderForm(
  communityRules = [
    { id: "spam", ground: "No spam" },
    { id: "abuse", ground: "Be civil" },
  ],
  hasDetails = false
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
        @hasActionDetails={{hasDetails}}
        @options={{options}}
        @reviewableId={{42}}
        as |flow|
      >
        <flow.Body />
        <footer><flow.Footer @submitLabel="Confirm" /></footer>
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
      assert.dom(suggest).doesNotExist();
    });

    test("starts once on open, shows progress on the button and allows an explicit retry", async function (assert) {
      const requests = [];
      pretender.post(
        endpoint,
        (request) => {
          requests.push(request);
          return response({ community_rule: "spam", category: "fraud" });
        },
        true
      );
      const rendered = renderForm(undefined, true);
      await waitUntil(() => requests.length === 1);
      assert
        .dom(".dsa-classification-footer")
        .hasAttribute("hidden", "", "starts during action details");
      assert.dom(suggest).isDisabled("prevents overlapping requests");
      assert
        .dom(`${suggest} .d-icon-spinner`)
        .exists("shows progress on the button");
      assert.dom(hint).doesNotExist("leaves pending fields unlabeled");
      pretender.resolve(requests[0]);
      await rendered;
      await click(".btn-primary");
      await click("footer > button.btn-flat");
      await click(".btn-primary");
      assert.strictEqual(
        requests.length,
        1,
        "changing steps does not reclassify"
      );
      await formKit().field("category").select("other");
      assert
        .dom(`${category} ${hint}`)
        .doesNotExist("clears attribution on edit");
      const clicked = click(suggest);
      await waitUntil(() => requests.length === 2);
      assert.dom(suggest).isDisabled("locks the retry button");
      pretender.resolve(requests[1]);
      await clicked;
      assert
        .dom(`${category} select`)
        .hasValue("fraud", "reapplies the suggestion on request");
      assert
        .dom(`${category} ${hint}`)
        .hasText("Suggested by AI", "restores attribution");
    });

    test("uses the error dialog and keeps the button available for retry", async function (assert) {
      const alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");
      pretender.post(endpoint, () => controllerRateLimit());
      await renderForm();
      assert.true(alert.calledOnce, "reports the failed request in the dialog");
      assert.dom(hint).doesNotExist("leaves the fields free of error messages");
      assert.dom(suggest).isEnabled("allows trying again");
      pretender.post(endpoint, () => response({ category: "fraud" }));
      await click(suggest);
      assert
        .dom(`${category} ${hint}`)
        .hasText("Suggested by AI", "labels the successful retry");
      assert
        .dom(`${rule} ${hint}`)
        .doesNotExist("leaves omitted fields unlabeled");
    });

    test("attributes only the suggested category when the form has a sole rule", async function (assert) {
      pretender.post(endpoint, () =>
        response({ community_rule: "spam", category: "fraud" })
      );
      await renderForm([{ id: "spam", ground: "No spam" }]);
      assert
        .dom(".dsa-classification-select")
        .hasText("No spam", "preserves the sole rule");
      assert
        .dom(`${rule} ${hint}`)
        .doesNotExist("does not attribute the site's default");
      assert.dom(`${category} ${hint}`).hasText("Suggested by AI");
    });
  }
);
