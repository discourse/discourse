import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import AiFeatureAgentGroups from "discourse/plugins/discourse-ai/discourse/components/ai-feature-agent-groups";

module("Integration | Component | AiFeatureAgentGroups", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    pretender.get("/groups/search.json", () =>
      response([
        { id: 10, name: "trust_level_0" },
        { id: 3, name: "staff" },
      ])
    );
  });

  test("shows who can use the feature", async function (assert) {
    const agent = { id: 5, allowed_groups: [] };

    await render(
      <template>
        <AiFeatureAgentGroups @agent={{agent}} @featureName="Explain" />
      </template>
    );

    assert
      .dom(".ai-features-feature-row__empty")
      .hasText(i18n("discourse_ai.features.who_can_use.no_one"));
    assert
      .dom(".ai-feature-agent-groups__edit")
      .hasAria(
        "label",
        i18n("discourse_ai.features.who_can_use.edit", { name: "Explain" })
      );
  });

  test("offers everyone when group search omits it", async function (assert) {
    let saved;
    pretender.put("/admin/plugins/discourse-ai/ai-agents/5.json", (request) => {
      saved = JSON.parse(request.requestBody);
      return response({ ai_agent: {} });
    });
    const agent = { id: 5, allowed_groups: [] };
    await render(
      <template>
        <AiFeatureAgentGroups @agent={{agent}} @featureName="Explain" />
      </template>
    );
    await click(".ai-feature-agent-groups__edit");
    const chooser = selectKit(".ai-feature-agent-groups .select-kit");
    await chooser.expand();
    await chooser.selectRowByValue(0);
    await click(".ai-feature-agent-groups__save");
    assert.deepEqual(
      saved,
      { ai_agent: { allowed_group_ids: [0] } },
      "everyone remains selectable even when the endpoint omits it"
    );
  });

  test("saves the agent's groups, including none", async function (assert) {
    let saved;
    let changed = false;
    pretender.put("/admin/plugins/discourse-ai/ai-agents/5.json", (request) => {
      saved = JSON.parse(request.requestBody);
      return response({ ai_agent: {} });
    });
    const agent = {
      id: 5,
      allowed_groups: [{ id: 10, name: "trust_level_0" }],
    };
    const onChange = () => (changed = true);

    await render(
      <template>
        <AiFeatureAgentGroups
          @agent={{agent}}
          @featureName="Explain"
          @onChange={{onChange}}
        />
      </template>
    );
    await click(".ai-feature-agent-groups__edit");

    const chooser = selectKit(".ai-feature-agent-groups .select-kit");
    await chooser.expand();
    await chooser.deselectItemByValue("10");

    assert
      .dom(".ai-feature-agent-groups__warning")
      .exists("warns that no one will be able to use it");

    await click(".ai-feature-agent-groups__save");

    assert.deepEqual(saved, { ai_agent: { allowed_group_ids: [] } });
    assert.true(changed, "reloads the features");
    assert.dom(".ai-feature-agent-groups .select-kit").doesNotExist();
  });

  test("a failed group lookup leaves the editor usable for a retry", async function (assert) {
    const alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");
    pretender.get("/groups/search.json", () =>
      response(500, { errors: ["Groups unavailable"] })
    );
    const agent = { id: 5, allowed_groups: [] };
    await render(
      <template>
        <AiFeatureAgentGroups @agent={{agent}} @featureName="Explain" />
      </template>
    );
    await click(".ai-feature-agent-groups__edit");
    assert.true(alert.calledOnce, "reports the lookup failure");
    assert
      .dom(".ai-feature-agent-groups .select-kit")
      .doesNotExist("keeps the empty editor closed");
    pretender.get("/groups/search.json", () =>
      response([{ id: 3, name: "staff" }])
    );
    await click(".ai-feature-agent-groups__edit");
    assert
      .dom(".ai-feature-agent-groups .select-kit")
      .exists("the next attempt can open the editor");
  });

  test("warns when the agent is shared with other features", async function (assert) {
    const agent = { id: 5, allowed_groups: [] };
    const sharedWith = [{ module_name: "ai_helper", name: "translator" }];

    await render(
      <template>
        <AiFeatureAgentGroups
          @agent={{agent}}
          @featureName="Explain"
          @sharedWith={{sharedWith}}
        />
      </template>
    );
    await click(".ai-feature-agent-groups__edit");

    assert.dom(".ai-feature-agent-groups__shared").hasText(
      i18n("discourse_ai.features.who_can_use.shared", {
        features: i18n("discourse_ai.features.ai_helper.translator"),
      })
    );
  });
});
