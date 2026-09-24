import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Reactions from "discourse/plugins/discourse-rewind/discourse/components/reports/reactions";

module("Integration | Component | Reports | Reactions", function (hooks) {
  setupRenderingTest(hooks);

  test("without received reactions", async function (assert) {
    const report = {
      data: {
        post_used_reactions: [{ emoji: "heart", count: 2 }],
        post_used_reactions_total: 2,
        post_received_reactions: [],
      },
    };

    await render(<template><Reactions @report={{report}} /></template>);

    assert
      .dom(".rewind-report-page.--post-used-reactions")
      .exists("the used reactions render");
    assert
      .dom(".rewind-report-page.--post-received-reactions")
      .doesNotExist("the received reactions are not rendered");
  });

  test("without used reactions", async function (assert) {
    const report = {
      data: {
        post_used_reactions: [],
        post_used_reactions_total: 0,
        post_received_reactions: [{ emoji: "otter", count: 1 }],
      },
    };

    await render(<template><Reactions @report={{report}} /></template>);

    assert
      .dom(".rewind-report-page.--post-used-reactions")
      .doesNotExist("the used reactions are not rendered");
    assert
      .dom(".rewind-report-page.--post-received-reactions")
      .exists("the received reactions render");
  });
});
