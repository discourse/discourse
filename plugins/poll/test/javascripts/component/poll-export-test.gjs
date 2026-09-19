import EmberObject from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { OK } from "discourse/tests/helpers/create-pretender";
import Poll from "discourse/plugins/poll/discourse/components/poll";

const BOM = "﻿";
const CSV_ROWS = "option,votes\n晚凪,3\n";

module("Component | Poll | export", function (hooks) {
  setupRenderingTest(hooks);

  let downloadedBlob;
  let originalCreateObjectURL;

  hooks.beforeEach(function () {
    downloadedBlob = null;
    originalCreateObjectURL = URL.createObjectURL;
    URL.createObjectURL = (blob) => {
      downloadedBlob = blob;
      return "blob:stubbed";
    };

    this.siteSettings.data_explorer_enabled = true;
    this.siteSettings.poll_export_data_explorer_query_id = 18;
    this.currentUser.admin = true;

    pretender.post(
      "/admin/plugins/discourse-data-explorer/queries/18/run.csv",
      () => OK(CSV_ROWS, { "Content-Type": "text/csv" })
    );
  });

  hooks.afterEach(function () {
    URL.createObjectURL = originalCreateObjectURL;
  });

  test("the downloaded CSV carries exactly one UTF-8 BOM", async function (assert) {
    this.setProperties({
      post: EmberObject.create({
        id: 42,
        topic: { archived: false },
        user_id: 29,
      }),
      poll: EmberObject.create({
        name: "poll",
        type: "regular",
        status: "open",
        results: "always",
        options: [{ id: "abc", html: "晚凪", votes: 3 }],
        voters: 3,
        chart_type: "bar",
      }),
    });

    await render(
      <template><Poll @poll={{this.poll}} @post={{this.post}} /></template>
    );
    await click(".widget-dropdown-header");
    await click(".export-results");

    const text = new TextDecoder("utf-8", { ignoreBOM: true }).decode(
      await downloadedBlob.arrayBuffer()
    );

    assert.strictEqual(text, BOM + CSV_ROWS, "exactly one BOM is prepended");
  });
});
