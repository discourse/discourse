import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiModelNew from "discourse/plugins/discourse-ai/discourse/components/ai-model-new";

class AdminPluginNavManagerStub extends Service {
  currentPlugin = { name: "discourse-ai" };
}

module("Integration | Component | AiModelNew", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:admin-plugin-nav-manager");
    this.owner.register(
      "service:admin-plugin-nav-manager",
      AdminPluginNavManagerStub
    );
  });

  test("links each type card to its guide", async function (assert) {
    const empty = { content: [], resultSetMeta: { presets: [] } };

    await render(
      <template>
        <AiModelNew
          @decisionModels={{empty}}
          @embeddings={{empty}}
          @llms={{empty}}
        />
      </template>
    );

    assert
      .dom("[data-model-type='llm'] .admin-section-landing-item__description a")
      .hasAttribute("href", /\/319903$/);
    assert
      .dom(
        "[data-model-type='embedding'] .admin-section-landing-item__description a"
      )
      .hasAttribute("href", /\/259603$/);
    assert
      .dom(
        "[data-model-type='decision'] .admin-section-landing-item__description a"
      )
      .hasAttribute("href", /\/414738$/);
  });
  test("offers decision creation with workflows disabled and no configured models", async function (assert) {
    this.siteSettings.enable_discourse_workflows = false;
    const empty = { content: [], resultSetMeta: { presets: [] } };
    await render(
      <template>
        <AiModelNew
          @decisionModels={{empty}}
          @embeddings={{empty}}
          @llms={{empty}}
          @type="decision"
        />
      </template>
    );
    const transitionTo = sinon.spy();
    this.owner.lookup("service:router").transitionTo = transitionTo;
    assert
      .dom(".admin-section-landing-item")
      .exists("offers a manual decision model template");
    assert
      .dom(".admin-section-landing-item")
      .includesText(
        "Manual configuration",
        "can configure a decision model without a preset"
      );
    await click('[data-template-id="none"] button');
    assert.true(
      transitionTo.calledWith(
        "adminPlugins.show.discourse-ai-decision-models.new",
        { queryParams: { preset: null } }
      ),
      "opens decision model creation"
    );
  });
});
