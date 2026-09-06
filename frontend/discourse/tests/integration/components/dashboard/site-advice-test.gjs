import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSiteAdvice from "discourse/admin/components/dashboard/site-advice";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | DashboardSiteAdvice", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    logIn(getOwner(this));
    updateCurrentUser({ admin: true });
  });

  test("rewrites setting links in problem messages via the modifier", async function (assert) {
    const rewrittenURL =
      "/admin/config/onebox?filter=github_onebox_access_tokens";
    const dataSource = this.owner.lookup("service:admin-search-data-source");
    dataSource.urlForSetting = ({ setting }) =>
      setting === "github_onebox_access_tokens" ? rewrittenURL : null;

    const problems = [
      {
        id: 1,
        priority: "low",
        message:
          'Configuring <a class="site-setting-link" href="/admin/site_settings/category/all_results?filter=github_onebox_access_tokens" data-setting-name="github_onebox_access_tokens" data-setting-category="onebox">GitHub onebox access tokens</a> raises the limit.',
      },
    ];

    await render(
      <template><DashboardSiteAdvice @problems={{problems}} /></template>
    );

    assert
      .dom(".db-site-advice__message a.site-setting-link")
      .hasText("GitHub onebox access tokens")
      .hasAttribute("href", rewrittenURL);
  });
});
