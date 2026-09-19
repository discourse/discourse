import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";
import LivestreamZoomEntry from "../../discourse/components/livestream/zoom-entry";
import DiscoursePostEventEvent from "../../discourse/models/discourse-post-event-event";

const JOIN_BUTTON_SELECTOR =
  ".discourse-calendar-livestream-zoom-entry .discourse-calendar-livestream-zoom-entry__join";
const WAITING_SELECTOR = ".discourse-calendar-livestream-zoom-entry__waiting";

module("Integration | Component | LivestreamZoomEntry", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.livestream_zoom_enabled = true;

    this.event = {
      id: 42,
      currentlyWithinEventTimeframe: true,
      pastEventTimeframe: false,
      livestreamChatChannelId: 9,
      post: {
        topic: {
          id: 1,
          slug: "test-topic",
          chat_channel_id: 9,
        },
      },
    };
  });

  test("links to the zoom page, which the meeting takes over in place", async function (assert) {
    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).hasTagName("a");
    assert.dom(JOIN_BUTTON_SELECTOR).hasText("Join Zoom");
    assert
      .dom(JOIN_BUTTON_SELECTOR)
      .hasAttribute(
        "href",
        "/t/test-topic/1/zoom",
        "the link is a real one, so it can be opened however the user likes"
      );
    assert
      .dom(JOIN_BUTTON_SELECTOR)
      .doesNotHaveAttribute(
        "target",
        "the meeting is the page, so it is not sent off to a window of its own"
      );
    assert
      .dom(".discourse-calendar-livestream-zoom-entry__frame")
      .doesNotExist("inline embedding was replaced by the /zoom route");
  });

  test("asks for the zoom route by name rather than leaving the click to the interceptor", async function (assert) {
    const transitionTo = sinon.stub(
      getOwner(this).lookup("service:router"),
      "transitionTo"
    );

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    await click(JOIN_BUTTON_SELECTOR);

    assert.true(
      transitionTo.calledWith("topic-zoom", "test-topic", 1),
      "the meeting is reached, not the topic it hangs off"
    );
  });

  test("disables the join button outside the event timeframe", async function (assert) {
    this.event.currentlyWithinEventTimeframe = false;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).isDisabled();
    assert
      .dom(WAITING_SELECTOR)
      .hasText("You can join the webinar closer to the event start time");
  });

  test("allows joining a multi-day all-day event through its end date", async function (assert) {
    const clock = fakeTime("2026-08-20T12:00:00Z", "UTC");
    this.event = DiscoursePostEventEvent.create({
      id: 42,
      starts_at: "2026-08-19T00:00:00Z",
      ends_at: "2026-08-21T00:00:00Z",
      all_day: true,
      livestream_chat_channel_id: 9,
      post: { topic: { id: 1, slug: "test-topic", chat_channel_id: 9 } },
    });

    try {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert
        .dom(JOIN_BUTTON_SELECTOR)
        .hasAttribute(
          "href",
          "/t/test-topic/1/zoom",
          "the event remains joinable between its start and end dates"
        );
    } finally {
      clock.restore();
    }
  });

  test("renders nothing after a multi-day all-day event's end date", async function (assert) {
    const clock = fakeTime("2026-08-22T12:00:00Z", "UTC");
    this.event = DiscoursePostEventEvent.create({
      id: 42,
      starts_at: "2026-08-19T00:00:00Z",
      ends_at: "2026-08-21T00:00:00Z",
      all_day: true,
      livestream_chat_channel_id: 9,
      post: { topic: { id: 1, slug: "test-topic", chat_channel_id: 9 } },
    });

    try {
      await render(
        <template><LivestreamZoomEntry @event={{this.event}} /></template>
      );

      assert
        .dom(".discourse-calendar-livestream-zoom-entry")
        .doesNotExist("the event is past after its final day");
    } finally {
      clock.restore();
    }
  });

  test("renders nothing once the event is past its grace period", async function (assert) {
    this.event.pastEventTimeframe = true;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").doesNotExist();
  });

  test("renders nothing when Zoom livestreams are disabled", async function (assert) {
    getOwner(this).lookup("service:site-settings").livestream_zoom_enabled =
      false;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").doesNotExist();
  });

  test("renders nothing without a livestream chat channel", async function (assert) {
    this.event.livestreamChatChannelId = null;

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(".discourse-calendar-livestream-zoom-entry").doesNotExist();
  });

  test("asks an anonymous user to sign up instead of linking them out", async function (assert) {
    const owner = getOwner(this);
    owner.unregister("service:current-user");

    const send = sinon.spy();
    owner.unregister("route:application");
    owner.register("route:application", { send }, { instantiate: false });

    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.dom(JOIN_BUTTON_SELECTOR).hasText("Join Zoom");
    assert
      .dom(JOIN_BUTTON_SELECTOR)
      .hasTagName(
        "button",
        "there is nothing to link to: the meeting is only served to a signed-in user"
      );

    await click(JOIN_BUTTON_SELECTOR);

    assert.true(
      send.calledWith("showCreateAccount"),
      "the signup modal stands in for the meeting"
    );
  });
});
