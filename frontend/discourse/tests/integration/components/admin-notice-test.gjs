import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminNotice from "discourse/admin/components/admin-notice";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | AdminNotice", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    logIn(getOwner(this));
    updateCurrentUser({ admin: true });
  });

  test("rewrites setting links in the problem message via the modifier", async function (assert) {
    const rewrittenURL =
      "/admin/config/onebox?filter=github_onebox_access_tokens";
    const dataSource = this.owner.lookup("service:admin-search-data-source");
    dataSource.urlForSetting = ({ setting }) =>
      setting === "github_onebox_access_tokens" ? rewrittenURL : null;

    const problem = {
      message:
        'Configuring <a class="site-setting-link" href="/admin/site_settings/category/all_results?filter=github_onebox_access_tokens" data-setting-name="github_onebox_access_tokens" data-setting-category="onebox">GitHub onebox access tokens</a> raises the limit.',
    };

    await render(<template><AdminNotice @problem={{problem}} /></template>);

    assert
      .dom(".message a.site-setting-link")
      .hasText("GitHub onebox access tokens")
      .hasAttribute("href", rewrittenURL);
  });
});
