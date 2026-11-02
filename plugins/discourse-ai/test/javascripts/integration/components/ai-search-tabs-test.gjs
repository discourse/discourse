import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiSearchTabs from "discourse/plugins/discourse-ai/discourse/components/ai-search/ai-search-tabs";

module("Integration | Component | AiSearchTabs", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.register(
      "service:ai-search-session",
      class extends Service {
        @tracked selectedTab = null;
        @tracked topicsResults = null;
        @tracked contextResults = null;
        @tracked answerFailed = false;
        scope = null;

        selectTab(tab) {
          this.selectedTab = tab;
        }
      }
    );
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
});
