import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Location from "discourse/plugins/discourse-calendar/discourse/components/discourse-post-event/location";

module(
  "Integration | Component | DiscoursePostEventLocation",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a plain-text location", async function (assert) {
      await render(
        <template><Location @location="Conference Room A" /></template>
      );

      assert
        .dom(".event-location")
        .includesText("Conference Room A", "shows the location text");
    });

    test("renders a URL location as a plain link, never a onebox", async function (assert) {
      await render(
        <template>
          <Location @location="https://youtube.com/watch?v=123" />
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

    test("links urls inside surrounding text", async function (assert) {
      await render(
        <template>
          <Location @location="Zoom: https://zoom.us/j/123 (room 2)" />
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
