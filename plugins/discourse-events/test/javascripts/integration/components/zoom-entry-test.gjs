import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LivestreamZoomEntry from "../../discourse/components/livestream/zoom-entry";

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

  test("tags the body while the zoom entry is on screen", async function (assert) {
    await render(
      <template><LivestreamZoomEntry @event={{this.event}} /></template>
    );

    assert.true(
      document.body.classList.contains(
        "discourse-calendar-livestream-zoom-topic"
      ),
      "the header icon is hidden by CSS while the zoom entry is present"
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
