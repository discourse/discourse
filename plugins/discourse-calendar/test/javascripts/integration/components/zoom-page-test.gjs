import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LivestreamZoomPage from "../../discourse/components/livestream/zoom-page";

const FALLBACK_SELECTOR = ".discourse-calendar-livestream-zoom-page__fallback";
const FRAME_SELECTOR = ".discourse-calendar-livestream-zoom-page__frame";
const CHAT_BUTTON_SELECTOR =
  ".discourse-calendar-livestream-zoom-page__chat-button";
const WAITING_SELECTOR = ".discourse-calendar-livestream-zoom-page__waiting";
const ERROR_TEXT =
  "You left the webinar or we are unable to load Zoom in this page.";

// `returnedFromZoom` reads `window.location.search`, which a rendering test
// cannot set. Stubbing the getter is the only way to reach the branch.
function stubReturnedFromZoom(value) {
  sinon.stub(LivestreamZoomPage.prototype, "returnedFromZoom").get(() => value);
}

// `loadZoom` is an `@action`, so the prototype holds an accessor rather than a
// plain method and a bare `sinon.stub` would leave the real one in place — it
// would reach for the network and the Zoom SDK.
function stubLoadZoom(implementation) {
  const fake = sinon.fake(implementation ?? (() => Promise.resolve()));

  sinon.stub(LivestreamZoomPage.prototype, "loadZoom").get(function () {
    return fake.bind(this);
  });

  return fake;
}

module("Integration | Component | LivestreamZoomPage", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    getOwner(this).lookup("service:site-settings").chat_enabled = true;

    this.topic = {
      id: 1,
      slug: "test-topic",
      chat_channel_id: 9,
      postStream: {
        posts: [
          {
            event: {
              livestream_url: "https://us06web.zoom.us/j/123456789",
              starts_at: moment().subtract(5, "minutes").toISOString(),
              ends_at: moment().add(1, "hour").toISOString(),
            },
          },
        ],
      },
    };
  });

  test("loads Zoom once into the frame", async function (assert) {
    const loadZoom = stubLoadZoom();
    stubReturnedFromZoom(false);

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(FRAME_SELECTOR).exists();
    assert.dom(FALLBACK_SELECTOR).doesNotExist("no error before a failure");
    assert.strictEqual(loadZoom.callCount, 1, "sets the SDK up exactly once");
  });

  // Simulates navigating straight to /t/:slug/:id/zoom before the join window
  // opens, bypassing the disabled button on the topic page.
  test("does not load Zoom before the event timeframe", async function (assert) {
    const loadZoom = stubLoadZoom();
    stubReturnedFromZoom(false);
    this.topic.postStream.posts[0].event.starts_at = moment()
      .add(2, "hours")
      .toISOString();

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(FRAME_SELECTOR).doesNotExist();
    assert
      .dom(WAITING_SELECTOR)
      .hasText("You can join the webinar closer to the event start time");
    assert.strictEqual(loadZoom.callCount, 0, "never sets the SDK up");
  });

  test("does not load Zoom after the event timeframe", async function (assert) {
    const loadZoom = stubLoadZoom();
    stubReturnedFromZoom(false);
    this.topic.postStream.posts[0].event.starts_at = moment()
      .subtract(3, "hours")
      .toISOString();
    this.topic.postStream.posts[0].event.ends_at = moment()
      .subtract(1, "hour")
      .toISOString();

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(FRAME_SELECTOR).doesNotExist();
    assert.dom(WAITING_SELECTOR).exists();
    assert.strictEqual(loadZoom.callCount, 0, "never sets the SDK up");
  });

  test("shows the fallback link when Zoom fails to load", async function (assert) {
    stubLoadZoom(function () {
      this.errorMessage = ERROR_TEXT;
      return Promise.resolve();
    });
    stubReturnedFromZoom(false);

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(FALLBACK_SELECTOR).exists();
    assert.dom(`${FALLBACK_SELECTOR} p`).hasText(ERROR_TEXT);
    assert
      .dom(`${FALLBACK_SELECTOR} .btn-primary`)
      .doesNotExist("no retry button unless the user came back from Zoom");
  });

  test("offers a retry when the user has returned from Zoom", async function (assert) {
    stubReturnedFromZoom(true);

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert
      .dom(`${FALLBACK_SELECTOR} p`)
      .hasText(ERROR_TEXT, "does not try to rejoin automatically");
    assert.dom(`${FALLBACK_SELECTOR} .btn-primary`).hasText("Join Zoom");
  });

  test("offers to open the chat when the topic has a channel", async function (assert) {
    stubLoadZoom();
    stubReturnedFromZoom(false);

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(CHAT_BUTTON_SELECTOR).exists();
  });

  test("hides the chat button when chat is disabled", async function (assert) {
    stubLoadZoom();
    stubReturnedFromZoom(false);
    getOwner(this).lookup("service:site-settings").chat_enabled = false;

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(CHAT_BUTTON_SELECTOR).doesNotExist();
  });

  test("hides the chat button when the topic has no channel", async function (assert) {
    stubLoadZoom();
    stubReturnedFromZoom(false);
    this.topic.chat_channel_id = null;

    await render(
      <template><LivestreamZoomPage @topic={{this.topic}} /></template>
    );

    assert.dom(CHAT_BUTTON_SELECTOR).doesNotExist();
  });
});
