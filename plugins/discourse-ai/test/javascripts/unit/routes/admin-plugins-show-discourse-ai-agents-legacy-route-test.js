import { module, test } from "qunit";
import AdminPluginsShowDiscourseAiAgentsLegacy from "discourse/plugins/discourse-ai/discourse/routes/admin-plugins/show/discourse-ai-agents-legacy";

module(
  "Unit | Route | admin-plugins-show-discourse-ai-agents-legacy",
  function () {
    test("it redirects the legacy index route via URL", function (assert) {
      const route = AdminPluginsShowDiscourseAiAgentsLegacy.create();
      let redirectArgs;

      route.replaceWith = (...args) => (redirectArgs = args);

      route.beforeModel({
        intent: { url: "/admin/plugins/discourse-ai/ai-personas" },
      });

      assert.deepEqual(redirectArgs, ["/admin/plugins/discourse-ai/ai-agents"]);
    });

    test("it redirects the legacy new route via URL", function (assert) {
      const route = AdminPluginsShowDiscourseAiAgentsLegacy.create();
      let redirectArgs;

      route.replaceWith = (...args) => (redirectArgs = args);

      route.beforeModel({
        intent: { url: "/admin/plugins/discourse-ai/ai-personas/new" },
      });

      assert.deepEqual(redirectArgs, [
        "/admin/plugins/discourse-ai/ai-agents/new",
      ]);
    });

    test("it redirects the legacy edit route via URL", function (assert) {
      const route = AdminPluginsShowDiscourseAiAgentsLegacy.create();
      let redirectArgs;

      route.replaceWith = (...args) => (redirectArgs = args);

      route.beforeModel({
        intent: { url: "/admin/plugins/discourse-ai/ai-personas/123/edit" },
      });

      assert.deepEqual(redirectArgs, [
        "/admin/plugins/discourse-ai/ai-agents/123/edit",
      ]);
    });

    test("it falls back to named route when URL is unavailable", function (assert) {
      const route = AdminPluginsShowDiscourseAiAgentsLegacy.create();
      let redirectArgs;

      route.replaceWith = (...args) => (redirectArgs = args);

      route.beforeModel({ intent: {} });

      assert.deepEqual(redirectArgs, ["adminPlugins.show.discourse-ai-agents"]);
    });
  }
);
