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

  test("renders the custom SVGs on the five word cards", async function (assert) {
    pretender.get("/rewinds.json", () =>
      response({
        reports: [
          {
            identifier: "top-words",
            data: [
              { word: "pumpkin", score: 7 },
              { word: "pepper", score: 6 },
              { word: "carrot", score: 5 },
              { word: "tomato", score: 4 },
              { word: "cucumber", score: 3 },
            ],
          },
        ],
        total_available: 1,
      })
    );

    await render(<template><Rewind @user={{this.currentUser}} /></template>);

    const icons = [
      "floppy-disk",
      "videocassette",
      "computer-disk",
      "pager",
      "fax",
    ];
    for (const [index, icon] of icons.entries()) {
      assert
        .dom(
          `.rewind-words__slot:nth-child(${index + 1}) .rewind-word-card__icon`
        )
        .hasAttribute(
          "src",
          new RegExp(`/plugins/discourse-rewind/images/one-bit/${icon}\\.svg$`),
          `card ${index + 1} has a URL for the ${icon} SVG`
        );
    }
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
