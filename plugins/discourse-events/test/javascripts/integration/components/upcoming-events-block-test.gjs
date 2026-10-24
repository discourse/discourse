import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet from "discourse/blocks/block-outlet";
import { resetBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import UpcomingEventsBlock from "../../discourse/blocks/upcoming-events";

const TODAY = "2100-02-01T08:00:00";
const TOMORROW = "2100-02-02T08:00:00";

function oneEventResponse() {
  return response({
    events: [
      {
        id: 1,
        starts_at: TOMORROW,
        ends_at: null,
        timezone: "UTC",
        post: {
          id: 1,
          post_number: 1,
          url: "/t/an-event/1/1",
          topic: { id: 1, title: "An event" },
        },
        name: "Awesome Event",
        category_id: 1,
      },
    ],
  });
}

// The reserved-space skeleton + the pending/loading transition are covered
// generically by the core block-data integration tests; here we verify the
// block wires its data through the data layer and keeps its chrome.
module("Integration | Block | upcoming-events", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.clock = fakeTime(TODAY, null, true);
  });

  hooks.afterEach(function () {
    this.clock.restore();
    resetBlockData();
  });

  test("renders the heading chrome and the events from the data layer", async function (assert) {
    pretender.get("/discourse-post-event/events", oneEventResponse);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: UpcomingEventsBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".events-block-upcoming-events .d-block-panel__title")
      .exists("the panel heading renders");
    assert
      .dom(".upcoming-events-list__event-name")
      .hasText("Awesome Event", "the event renders from the resolved data");
    assert.dom(".d-skeleton").doesNotExist("no skeleton once resolved");
    assert
      .dom(".d-block-panel__footer .d-block-panel__link")
      .exists("the view all link shows by default");
  });

  test("shows the empty message when there are no events", async function (assert) {
    pretender.get("/discourse-post-event/events", () =>
      response({ events: [] })
    );

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: UpcomingEventsBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-panel__title").exists("the heading still renders");
    assert.dom(".d-block-panel__empty").exists("the empty block renders");
  });

  test("surfaces an inline error when the fetch fails", async function (assert) {
    pretender.get("/discourse-post-event/events", () => response(500, {}));

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: UpcomingEventsBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-panel__title").exists("the heading stays on failure");
    assert
      .dom(".hero-blocks__block .d-block-panel__error")
      .exists("the failure surfaces in the panel with a retry");
  });
});
