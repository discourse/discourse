import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiFeatureCard from "discourse/plugins/discourse-ai/discourse/components/ai-feature-card";

module("Integration | Component | AiFeatureCard", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.afterEach(() => setPrefix(""));

  test("renders deduplicated prefix-aware group card links", async function (assert) {
    setPrefix("/forum");
    this.feature = {
      name: "test_feature",
      enabled: true,
      llm_models: [],
      agents: [
        {
          id: 1,
          name: "First agent",
          allowed_groups: [
            { id: 10, name: "team" },
            { id: 11, name: "staff" },
          ],
        },
        {
          id: 2,
          name: "Second agent",
          allowed_groups: [{ id: 10, name: "team" }],
        },
      ],
    };

    await render(
      <template>
        <AiFeatureCard
          @feature={{this.feature}}
          @localizedFeatureName="Test feature"
          @showGroups={{true}}
        />
      </template>
    );

    assert
      .dom(".ai-feature-card__item-groups li")
      .exists({ count: 2 }, "renders each group once");
    assert
      .dom('.ai-feature-card__item-groups a[data-group-card="team"]')
      .exists({ count: 1 }, "deduplicates repeated groups")
      .hasClass("user-group", "uses the standard group link class")
      .hasClass("trigger-group-card", "triggers the standard group card")
      .hasClass("mention-group", "uses the standard group mention styling")
      .hasAttribute(
        "href",
        "/forum/g/team",
        "uses the prefix-aware group path"
      );
    assert
      .dom('.ai-feature-card__item-groups a[data-group-card="staff"]')
      .exists({ count: 1 }, "renders the other group")
      .hasAttribute("href", "/forum/g/staff", "prefixes every group path");
  });
});
