import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminReportStorageStats from "discourse/admin/components/admin-report-storage-stats";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

const MODEL = {
  data: {
    backups: { used_bytes: 1024, free_bytes: 2048, count: 3 },
    uploads: { used_bytes: 4096, free_bytes: null },
  },
};

module("Integration | Component | AdminReportStorageStats", function (hooks) {
  setupRenderingTest(hooks);

  test("shows backup stats to admins", async function (assert) {
    logIn(getOwner(this));
    updateCurrentUser({ admin: true });

    await render(
      <template><AdminReportStorageStats @model={{MODEL}} /></template>
    );

    assert.dom(".backups").exists("shows the backups section");
    assert.dom(".uploads").exists("shows the uploads section");
  });

  test("hides backup stats from moderators", async function (assert) {
    logIn(getOwner(this));
    updateCurrentUser({ admin: false, moderator: true });

    await render(
      <template><AdminReportStorageStats @model={{MODEL}} /></template>
    );

    assert.dom(".backups").doesNotExist();
    assert.dom(".uploads").exists();
  });
});
