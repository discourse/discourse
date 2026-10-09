import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Location from "discourse/plugins/discourse-events/discourse/components/discourse-post-event/location";

module(
  "Integration | Component | DiscoursePostEventLocation",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a plain-text location", async function (assert) {
      this.event = {
        location: "Conference Room A",
        locationHtml: "Conference Room A",
      };

      await render(<template><Location @event={{this.event}} /></template>);

      assert
        .dom(".event-location")
        .includesText("Conference Room A", "shows the location text");
      assert
        .dom(".event-location .d-icon-location-pin")
        .exists("a physical venue keeps the map pin");
    });

    test("renders server-rendered links and opens them in a new tab", async function (assert) {
      this.event = {
        location: "[RSVP](https://zoom.us/j/123) (room 2)",
        locationHtml:
          '<a href="https://zoom.us/j/123" rel="nofollow ugc">RSVP</a> (room 2)',
      };

      await render(<template><Location @event={{this.event}} /></template>);

      assert
        .dom(".event-location a")
        .hasAttribute("href", "https://zoom.us/j/123")
        .hasAttribute("target", "_blank")
        .hasAttribute("rel", "nofollow ugc noopener")
        .hasText("RSVP", "shows the link label");
      assert
        .dom(".event-location")
        .includesText("(room 2)", "keeps the text around the link");
      assert
        .dom(".event-location .d-icon-location-pin")
        .exists("a link plus surrounding text is still a place");
    });

    test("renders a URL-only location for non-Zoom events", async function (assert) {
      this.event = {
        location: "https://youtube.com/watch?v=123",
        locationHtml:
          '<a href="https://youtube.com/watch?v=123" rel="nofollow ugc">https://youtube.com/watch?v=123</a>',
      };

      await render(<template><Location @event={{this.event}} /></template>);

      assert
        .dom(".event-location a")
        .hasAttribute("href", "https://youtube.com/watch?v=123");
      assert
        .dom(".event-location .d-icon-link")
        .exists("an online venue reads as a link, not a place");
    });

    test("does not render the URL for Zoom-only livestreams", async function (assert) {
      this.event = {
        location: "https://zoom.us/j/123",
        locationHtml:
          '<a href="https://zoom.us/j/123" rel="nofollow ugc">https://zoom.us/j/123</a>',
        isZoomLivestream: true,
      };

      await render(<template><Location @event={{this.event}} /></template>);

      assert
        .dom(".event-location")
        .doesNotExist("does not show the location URL");
    });

    test("renders a Zoom livestream location that is more than the URL", async function (assert) {
      this.event = {
        location: "Zoom: https://zoom.us/j/123 (room 2)",
        locationHtml:
          'Zoom: <a href="https://zoom.us/j/123" rel="nofollow ugc">https://zoom.us/j/123</a> (room 2)',
        isZoomLivestream: true,
      };

      await render(<template><Location @event={{this.event}} /></template>);

      assert.dom(".event-location").includesText("(room 2)");
    });

    test("renders nothing without a location", async function (assert) {
      this.event = {};

      await render(<template><Location @event={{this.event}} /></template>);

      assert.dom(".event-location").doesNotExist();
    });
  }
);
