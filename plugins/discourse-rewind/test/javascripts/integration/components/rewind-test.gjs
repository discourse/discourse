import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";
import Rewind from "discourse/plugins/discourse-rewind/discourse/components/rewind";

module("Integration | Component | Rewind", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableLoadMoreObserver();
    this.observations = stubIntersectionObserver();
  });

  hooks.afterEach(function () {
    disableLoadMoreObserver();
  });

  test("pages through the reports, skipping missing ones", async function (assert) {
    const topWords = {
      identifier: "top-words",
      data: [{ word: "pumpkin", score: 7 }],
    };
    const requestedOffsets = [];
    pretender.get("/rewinds.json", (request) => {
      requestedOffsets.push(request.queryParams.offset);
      const reports =
        request.queryParams.offset === "0"
          ? [topWords, null, topWords]
          : [topWords];
      return response({ reports, total_available: 4 });
    });

    await render(<template><Rewind @user={{this.currentUser}} /></template>);
    await this.observations.at(-1).trigger();
    await this.observations.at(-1).trigger();

    assert
      .dom(".rewind-report")
      .exists({ count: 3 }, "the missing report is skipped");
    assert.deepEqual(
      requestedOffsets,
      ["0", "3"],
      "loading continues after the first page and stops after the last"
    );
  });
});
