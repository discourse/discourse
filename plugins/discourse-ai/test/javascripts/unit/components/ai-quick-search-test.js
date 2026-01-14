import { module, test } from "qunit";
import AiQuickSearch from "discourse/plugins/discourse-ai/discourse/connectors/search-menu-results-bottom/ai-quick-search";

module("Unit | Component | ai-quick-search", function () {
  module("shouldRender", function () {
    test("returns true when site setting is enabled", function (assert) {
      const siteSettings = {
        ai_embeddings_semantic_quick_search_enabled: true,
      };
      assert.true(AiQuickSearch.shouldRender({}, { siteSettings }));
    });

    test("returns false when site setting is disabled", function (assert) {
      const siteSettings = {
        ai_embeddings_semantic_quick_search_enabled: false,
      };
      assert.false(AiQuickSearch.shouldRender({}, { siteSettings }));
    });
  });
});
