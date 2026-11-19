import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupURL } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DCdnImg from "discourse/ui-kit/d-cdn-img";

module("Integration | ui-kit | DCdnImg", function (hooks) {
  setupRenderingTest(hooks);

  test("renders nothing without @src", async function (assert) {
    await render(<template><DCdnImg @height={{10}} @width={{20}} /></template>);

    assert.dom("img").doesNotExist("no image is rendered");
  });

  test("renders the image from the CDN with its size", async function (assert) {
    // The test setup restores the URL configuration before each test.
    setupURL("https://cdn.example.com", "http://localhost:3000", "");

    await render(
      <template>
        <DCdnImg
          class="logo"
          @height={{50}}
          @src="/uploads/logo.png"
          @width={{100}}
        />
      </template>
    );

    assert
      .dom("img.logo")
      .hasAttribute(
        "src",
        "https://cdn.example.com/uploads/logo.png",
        "src uses the CDN"
      )
      .hasAttribute("width", "100", "@width is set")
      .hasAttribute("height", "50", "@height is set")
      .hasAttribute("alt", "", "the image is decorative")
      .hasAttribute("style", "--aspect-ratio: 2;", "the aspect ratio is set");
  });

  test("sets no aspect ratio without both dimensions", async function (assert) {
    await render(
      <template><DCdnImg @src="/uploads/logo.png" @width={{100}} /></template>
    );

    assert.dom("img").doesNotHaveAttribute("style", "no aspect ratio is set");
  });
});
