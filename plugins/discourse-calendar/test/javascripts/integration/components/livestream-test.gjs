import { on } from "@ember/modifier";
import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Livestream from "../../discourse/components/discourse-post-event/livestream";
import ZoomMeetingSession from "../../discourse/lib/zoom-meeting-session";

const ZOOM_URL = "https://us06web.zoom.us/j/123456789?pwd=secret";
const ZOOM_ENTRY_SELECTOR = ".discourse-calendar-livestream-zoom-entry";

const FakeLazyVideo = <template>
  <button type="button" class="fake-lazy-video" {{on "click" @onLoadedVideo}}>
    play
  </button>
</template>;

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

    module("with a playable video", function (nestedHooks) {
      let preventCloak;

      nestedHooks.beforeEach(function () {
        this.event.isZoomLivestream = false;
        this.event.livestreamUrl =
          "https://www.youtube.com/watch?v=dQw4w9WgXcQ";
        this.event.livestreamOnebox =
          "<div class='lazy-video-container'></div>";

        sinon.stub(Livestream.prototype, "lazyVideo").get(() => FakeLazyVideo);
        sinon
          .stub(Livestream.prototype, "videoAttributes")
          .get(() => ({ providerName: "youtube", id: "dQw4w9WgXcQ" }));

        withPluginApi((api) => {
          preventCloak = sinon.stub(api, "preventCloak");
        });
      });

      test("keeps the post rendered once the video is playing", async function (assert) {
        this.post = { id: 42 };

        await render(
          <template>
            <Livestream @event={{this.event}} @post={{this.post}} />
          </template>
        );

        assert.dom(".event-livestream .fake-lazy-video").exists();
        assert.false(
          preventCloak.called,
          "cloaking is still allowed before playback starts"
        );

        await click(".fake-lazy-video");

        assert.true(
          preventCloak.calledWith(42),
          "prevents the post holding the player from being cloaked"
        );
      });

      test("does not prevent cloaking when rendered without a post", async function (assert) {
        await render(<template><Livestream @event={{this.event}} /></template>);

        await click(".fake-lazy-video");

        assert.false(
          preventCloak.called,
          "no post to keep rendered, e.g. in the calendar or onebox preview"
        );
      });
    });

    module("with a Zoom livestream", function (nestedHooks) {
      let preventCloak;

      nestedHooks.beforeEach(function () {
        const owner = getOwner(this);
        owner.unregister("service:discourse-post-event-api");
        owner.register(
          "service:discourse-post-event-api",
          { joinEvent: () => Promise.resolve() },
          { instantiate: false }
        );

        this.event.id = 7;
        this.event.currentlyWithinEventTimeframe = true;
        this.event.canUpdateAttendance = false;

        sinon.stub(ZoomMeetingSession.prototype, "performJoin").resolves();

        withPluginApi((api) => {
          preventCloak = sinon.stub(api, "preventCloak");
        });
      });

      test("keeps the post rendered once the webinar has joined", async function (assert) {
        this.post = { id: 42 };

        await render(
          <template>
            <Livestream @event={{this.event}} @post={{this.post}} />
          </template>
        );

        assert.false(
          preventCloak.called,
          "cloaking is still allowed before the user joins"
        );

        await click(".discourse-calendar-livestream-zoom-entry .btn-primary");

        assert.true(
          preventCloak.calledWith(42),
          "prevents the post holding the Zoom session from being cloaked"
        );
      });
    });
  }
);
