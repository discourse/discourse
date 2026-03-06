import { module, test } from "qunit";
import AdminPluginsShowDiscourseAiAgentsLegacy from "discourse/plugins/discourse-ai/discourse/routes/admin-plugins/show/discourse-ai-agents-legacy";
import AdminPluginsShowDiscourseAiAgentsLegacyEdit from "discourse/plugins/discourse-ai/discourse/routes/admin-plugins/show/discourse-ai-agents-legacy/edit";
import AdminPluginsShowDiscourseAiAgentsLegacyNew from "discourse/plugins/discourse-ai/discourse/routes/admin-plugins/show/discourse-ai-agents-legacy/new";

module(
  "Unit | Route | admin-plugins-show-discourse-ai-agents-legacy",
  function () {
    test("it redirects the legacy index route", function (assert) {
      const route = AdminPluginsShowDiscourseAiAgentsLegacy.create();
      let redirectArgs;

      route.replaceWith = (...args) => (redirectArgs = args);

      route.beforeModel();

      assert.deepEqual(redirectArgs, ["adminPlugins.show.discourse-ai-agents"]);
    });

    test("it redirects the legacy new route", function (assert) {
      const route = AdminPluginsShowDiscourseAiAgentsLegacyNew.create();
      let redirectArgs;

      route.replaceWith = (...args) => (redirectArgs = args);

      route.beforeModel();

      assert.deepEqual(redirectArgs, [
        "adminPlugins.show.discourse-ai-agents.new",
      ]);
    });

    test("it redirects the legacy edit route", function (assert) {
      const route = AdminPluginsShowDiscourseAiAgentsLegacyEdit.create();
      let redirectArgs;

      route.replaceWith = (...args) => (redirectArgs = args);

      route.model({ id: "123" });

      assert.deepEqual(redirectArgs, [
        "adminPlugins.show.discourse-ai-agents.edit",
        "123",
      ]);
    });
  }
);
