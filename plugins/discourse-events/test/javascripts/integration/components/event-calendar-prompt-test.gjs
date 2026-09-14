import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import Status from "../../discourse/components/discourse-post-event/status";
import Event from "../../discourse/models/discourse-post-event-event";

module("Integration | Component | EventCalendarPrompt", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.event_participation_buttons =
      "going|interested|not going";
    this.event = Event.create({
      id: 99,
      status: "public",
      sample_invitees: [],
      stats: {},
      creator: { id: 2 },
    });
    pretender.post("/discourse-post-event/events/99/invitees", (request) => {
      const params = new URLSearchParams(request.requestBody);
      return response({
        invitee: {
          id: 5,
          status: params.get("invitee[status]"),
          user: { id: this.currentUser.id },
          recurring: false,
          meta: {
            event_stats: { going: 1, interested: 0 },
            event_should_display_invitees: true,
          },
        },
      });
    });
    pretender.put("/discourse-post-event/events/99/invitees/5", (request) => {
      const params = new URLSearchParams(request.requestBody);
      return response({
        invitee: {
          id: 5,
          status: params.get("invitee[status]"),
          user: { id: this.currentUser.id },
          recurring: false,
          meta: {
            event_stats: { going: 1, interested: 0 },
            event_should_display_invitees: true,
          },
        },
      });
    });
    pretender.delete("/discourse-post-event/events/99/invitees/5", () => [
      204,
      {},
      "",
    ]);
    pretender.get("/calendar-subscriptions.json", () =>
      response({ has_subscription: false, subscribed_feeds: [] })
    );
  });

  test("appears again after leaving and rejoining, even after dismissal", async function (assert) {
    await render(<template><Status @event={{this.event}} /></template>);
    assert
      .dom(".event-calendar-prompt")
      .doesNotExist("does not prompt on initial load");
    await click(".going-button");
    assert
      .dom(".event-calendar-prompt")
      .includesText(
        "Add this event to your calendar?",
        "prompts after a successful Going RSVP"
      );
    await click(".event-calendar-prompt__heading button");
    assert.dom(".event-calendar-prompt").doesNotExist("dismisses the prompt");
    await click(".interested-button");
    assert
      .dom(".event-calendar-prompt")
      .doesNotExist("does not nag again for Interested");
    await click(".not-going-button");
    await click(".interested-button");
    assert
      .dom(".event-calendar-prompt")
      .exists("prompts again when becoming Interested");
    await click(".going-button");
    await click(".going-button");
    assert.dom(".event-calendar-prompt").doesNotExist("hides when leaving");
    await click(".going-button");
    assert
      .dom(".event-calendar-prompt")
      .exists("prompts again when rejoining as Going");
  });

  test("offers contextual guidance when events subscription URLs exist", async function (assert) {
    pretender.get("/calendar-subscriptions.json", () =>
      response({ has_subscription: true, subscribed_feeds: ["my_events"] })
    );
    await render(<template><Status @event={{this.event}} /></template>);
    await click(".interested-button");
    assert
      .dom(".event-calendar-prompt")
      .includesText(
        "Using your events subscription?",
        "acknowledges generated URLs without claiming synchronization"
      );
    assert
      .dom(".event-calendar-prompt__actions")
      .includesText("Add individually", "retains a manual fallback");
    await click(".not-going-button");
    assert.dom(".event-calendar-prompt").doesNotExist("hides when not going");
  });

  test("ignores subscription lookup failures after a successful RSVP", async function (assert) {
    pretender.get("/calendar-subscriptions.json", () => response(500, {}));
    await render(<template><Status @event={{this.event}} /></template>);
    await click(".going-button");
    assert
      .dom(".going-button")
      .hasAttribute("aria-pressed", "true", "keeps the successful RSVP");
    assert
      .dom(".event-calendar-prompt")
      .doesNotExist("does not infer subscription state on error");
  });
});
