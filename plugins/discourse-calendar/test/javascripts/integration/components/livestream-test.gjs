import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Livestream from "../../discourse/components/discourse-post-event/livestream";

const ZOOM_URL = "https://us06web.zoom.us/j/123456789?pwd=secret";
const ZOOM_ENTRY_SELECTOR = ".discourse-calendar-livestream-zoom-entry";

module(
  "Integration | Component | DiscoursePostEvent::Livestream",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      const owner = getOwner(this);

      owner.unregister("service:capabilities");
      owner.register(
        "service:capabilities",
        { viewport: { lg: true } },
        { instantiate: false }
      );

      owner.lookup("service:site-settings").livestream_zoom_enabled = true;

      this.event = {
        livestream: true,
        livestreamUrl: ZOOM_URL,
        livestreamChatChannelId: 9,
        isZoomLivestream: true,
        post: { topic: { id: 1, slug: "test-topic", chat_channel_id: 9 } },
      };
    });

    test("renders nothing when the event has no livestream", async function (assert) {
      this.event.livestream = false;

      await render(<template><Livestream @event={{this.event}} /></template>);

      assert.dom(".event-livestream").doesNotExist();
    });

    test("renders nothing when the livestream has no URL", async function (assert) {
      this.event.livestreamUrl = null;

      await render(<template><Livestream @event={{this.event}} /></template>);

      assert.dom(".event-livestream").doesNotExist();
    });

    test("renders the Zoom entry for a Zoom livestream", async function (assert) {
      await render(<template><Livestream @event={{this.event}} /></template>);

      assert.dom(ZOOM_ENTRY_SELECTOR).exists();
    });

    test("does not render the Zoom entry when Zoom is disabled", async function (assert) {
      getOwner(this).lookup("service:site-settings").livestream_zoom_enabled =
        false;

      await render(<template><Livestream @event={{this.event}} /></template>);

      assert.dom(ZOOM_ENTRY_SELECTOR).doesNotExist();
      assert
        .dom(".event-livestream")
        .exists("still renders the livestream section");
    });

    test("renders the onebox for a non-Zoom livestream", async function (assert) {
      this.event.isZoomLivestream = false;
      this.event.livestreamUrl = "https://example.com/live";
      this.event.livestreamOnebox = "<aside class='onebox'>cached</aside>";

      await render(<template><Livestream @event={{this.event}} /></template>);

      assert.dom(ZOOM_ENTRY_SELECTOR).doesNotExist();
      assert
        .dom(".event-livestream aside.onebox")
        .exists("renders the cached onebox");
    });

    test("renders nothing inside the section when the onebox has not warmed yet", async function (assert) {
      this.event.isZoomLivestream = false;
      this.event.livestreamUrl = "https://example.com/live";
      this.event.livestreamOnebox = null;

      await render(<template><Livestream @event={{this.event}} /></template>);

      assert.dom(".event-livestream").exists();
      assert.dom(".event-livestream aside.onebox").doesNotExist();
    });
  }
);
