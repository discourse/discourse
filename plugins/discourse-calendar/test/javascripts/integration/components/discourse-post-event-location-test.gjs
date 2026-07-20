import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import DiscoursePostEventLocation from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event/location";

module(
  "Integration | Component | DiscoursePostEventLocation",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a plain-text location", async function (assert) {
      this.event = { location: "Conference Room A" };

      await render(
        <template>
          <DiscoursePostEventLocation @event={{this.event}} />
        </template>
      );

      assert
        .dom(".event-location")
        .includesText("Conference Room A", "shows the location text");
    });

    test("renders a URL location as a plain link, never a onebox", async function (assert) {
      this.event = { location: "https://youtube.com/watch?v=123" };

      await render(
        <template>
          <DiscoursePostEventLocation @event={{this.event}} />
        </template>
      );

      assert
        .dom(".event-location a")
        .hasAttribute("href", "https://youtube.com/watch?v=123")
        .hasText("https://youtube.com/watch?v=123", "shows the raw url");
      assert
        .dom(".event-location a")
        .doesNotHaveClass(
          "onebox",
          "leaves no onebox markup for the composer's onebox pass to hydrate"
        );
    });

    test("renders a single URL location as Zoom-only text for Zoom livestreams", async function (assert) {
      this.event = {
        location: "https://zoom.us/j/123",
        isZoomLivestream: true,
      };

      await render(
        <template>
          <DiscoursePostEventLocation @event={{this.event}} />
        </template>
      );

      assert
        .dom(".event-location")
        .hasText(
          i18n("discourse_calendar.livestream.zoom.zoom_only"),
          "shows the Zoom-only location text"
        );
      assert
        .dom(".event-location a")
        .doesNotExist("does not link the raw Zoom URL");
    });

    test("links URLs inside surrounding text", async function (assert) {
      this.event = { location: "Zoom: https://zoom.us/j/123 (room 2)" };

      await render(
        <template>
          <DiscoursePostEventLocation @event={{this.event}} />
        </template>
      );

      assert
        .dom(".event-location a")
        .hasText("https://zoom.us/j/123", "links only the url part");
      assert
        .dom(".event-location")
        .includesText("Zoom:", "keeps the text before the url");
      assert
        .dom(".event-location")
        .includesText("(room 2)", "keeps the text after the url");
    });
  }
);
