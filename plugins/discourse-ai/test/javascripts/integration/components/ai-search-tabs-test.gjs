import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiSearchTabs from "discourse/plugins/discourse-ai/discourse/components/ai-search/ai-search-tabs";

module("Integration | Component | AiSearchTabs", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.session = this.owner.lookup("service:ai-search-session");
  });

  test("counts only the tabs beside the one that opened", async function (assert) {
    this.session.topicsResults = { posts: [{ id: 1 }, { id: 2 }] };

    await render(<template><AiSearchTabs /></template>);

    assert
      .dom(".ai-search-tabs__count")
      .doesNotExist("waits for a tab to be chosen");

    this.session.selectedTab = "ask";
    await settled();
    assert.dom(".--topics .ai-search-tabs__count").hasText("2");

    this.session.selectedTab = "topics";
    await settled();
    assert
      .dom(".--topics .ai-search-tabs__count")
      .doesNotExist("the open tab shows its results instead");
  });

  test("marks a finished answer while another tab is open", async function (assert) {
    const discoveries = this.session.discoveries;
    discoveries.activeRequestId = "request-id";
    discoveries.loadingDiscoveries = true;
    this.session.selectedTab = "topics";

    await render(<template><AiSearchTabs /></template>);

    assert
      .dom(".ai-search-tabs__ready")
      .doesNotExist("the answer is still loading");

    await discoveries.onDiscoveryUpdate({
      request_id: "request-id",
      ai_discover_reply: "An answer.",
      answerable: true,
      done: true,
    });
    await settled();

    assert
      .dom(".--ask .ai-search-tabs__ready .d-icon-check")
      .exists("the Ask AI tab shows a checkmark when the answer is ready");

    await click(".ai-search-tabs .--ask");

    assert
      .dom(".ai-search-tabs__ready")
      .doesNotExist("the badge is hidden while reading the answer");

    await click(".ai-search-tabs .--topics");

    assert
      .dom('.--ask[aria-selected="false"] .ai-search-tabs__ready .d-icon-check')
      .exists("the badge reappears when switching back to Topics");
  });
});
