import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSystem from "discourse/admin/components/dashboard/system";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Dashboard | System", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("uses local storage for capacity and renders a full disk bar", async function (assert) {
    const data = {
      version: {
        installed_version: "3.6.0",
        missing_versions_count: 0,
      },
      storage: {
        backups: {
          count: 1,
          remote: true,
          used_bytes: 1024,
        },
        uploads: {
          free_bytes: 0,
          remote: false,
          used_bytes: 2048,
        },
      },
    };

    await render(<template><DashboardSystem @data={{data}} /></template>);

    assert
      .dom(".db-system__block.--storage .db-system__value")
      .hasText(
        "2 KB used",
        "excludes remote storage from the local disk total"
      );
    assert
      .dom(".db-system__block.--storage .db-bar-track")
      .exists("renders a capacity bar when no local space remains");
    assert
      .dom(".db-system__block.--storage .db-bar-fill")
      .hasAttribute("style", /width:\s*100(?:\.0)?%/, "fills the storage bar");
  });
});
